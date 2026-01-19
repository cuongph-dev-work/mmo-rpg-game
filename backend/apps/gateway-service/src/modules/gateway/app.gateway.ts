import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { Logger } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { AuthApiService } from '../auth/auth-api.service';
import { WorldClientService } from '../world-client/world-client.service';
import { ConfigService } from '@nestjs/config';

interface AuthenticatedSocket extends WebSocket {
  userId?: string;
  characterId?: string;
}

@WebSocketGateway({ path: '/ws' })
export class AppGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(AppGateway.name);

  constructor(
    private readonly authService: AuthService,
    private readonly authApiService: AuthApiService,
    private readonly worldClientService: WorldClientService,
    private readonly configService: ConfigService,
  ) {}

  async handleConnection(client: AuthenticatedSocket, request: IncomingMessage) {
    this.logger.log(`New connection attempt`);
    const url = new URL(request.url, `http://${request.headers.host}`);
    const token = url.searchParams.get('token');

    if (!token) {
      this.logger.warn('Connection attempt missing token');
      client.close(1008, 'Token missing');
      return;
    }
    
    this.logger.log(`Found token, validating...`);

    const payload = this.authService.validateToken(token);
    if (!payload) {
      this.logger.warn('Connection attempt invalid token');
      client.close(1008, 'Invalid token');
      return;
    }

    client.userId = payload.userId;
    const gatewayId = this.configService.get<string>('GATEWAY_ID', 'gateway-1');
    
    await this.worldClientService.registerSession(payload.userId, gatewayId);
    this.logger.log(`User ${payload.userId} connected`);
    
    client.send(JSON.stringify({ event: 'welcome', data: { message: 'Connected to Gateway' } }));
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.userId) {
      await this.worldClientService.removeSession(client.userId);
      this.logger.log(`User ${client.userId} disconnected`);
    }
  }

  @SubscribeMessage('enter_world')
  async handleEnterWorld(
    @MessageBody() data: { character_id: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.userId) {
      this.logger.warn('enter_world attempt without userId');
      return;
    }

    const characterId = data.character_id;
    this.logger.log(`User ${client.userId} requesting to enter world with character ${characterId}`);

    try {
      // Verify character ownership
      const isOwner = await this.authApiService.verifyCharacterOwnership(characterId, client.userId);
      
      if (!isOwner) {
        this.logger.warn(`User ${client.userId} does not own character ${characterId}`);
        client.send(JSON.stringify({
          event: 'error',
          data: { code: 'FORBIDDEN', message: 'You do not own this character' }
        }));
        return;
      }

      // Fetch character data
      const character = await this.authApiService.getCharacterById(characterId);
      
      // Store character in socket
      client.characterId = characterId;

      // Request map allocation from world directory
      const mapServer = await this.worldClientService.getMapServer(character.map_id);

      if (!mapServer) {
        client.send(JSON.stringify({
          event: 'error',
          data: { code: 'MAP_NOT_FOUND', message: `Map ${character.map_id} not available` }
        }));
        return;
      }

      // For now, return mock data. In Phase 5, this will include real ticket from world-directory
      const response = {
        event: 'enter_world_success',
        data: {
          character_id: characterId,
          map_id: character.map_id,
          map_ip: mapServer.ip,
          map_port: mapServer.port,
          ticket: 'mock-ticket-' + characterId, // TODO: Generate real HMAC ticket
          spawn_pos: character.position
        }
      };

      this.logger.log(`Sending enter_world_success for character ${characterId}`);
      client.send(JSON.stringify(response));

    } catch (error) {
      this.logger.error(`enter_world failed: ${error.message}`);
      client.send(JSON.stringify({
        event: 'error',
        data: { code: 'INTERNAL_ERROR', message: 'Failed to process enter_world request' }
      }));
    }
  }

  @SubscribeMessage('join_map')
  async handleJoinMap(
    @MessageBody() data: { map_id: number },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.userId) return;

    this.logger.log(`User ${client.userId} requesting to join map ${data.map_id}`);
    const mapServer = await this.worldClientService.getMapServer(data.map_id);

    if (mapServer) {
        // In a real scenario, we might also ask the map server for a "ticket" here.
        // For MVP, we just return the IP/Port.
        const response = {
            event: 'join_map_success',
            data: {
                map_ip: mapServer.ip,
                map_port: mapServer.port,
                ticket: 'mock-ticket' // Phase 4 will use real ticket
            }
        };
        client.send(JSON.stringify(response));
    } else {
        client.send(JSON.stringify({
            event: 'error',
            data: { code: 'MAP_NOT_FOUND', message: `Map ${data.map_id} not available` }
        }));
    }
  }

  @SubscribeMessage('chat')
  handleChat(
    @MessageBody() data: { message: string },
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.userId) return;

    const broadcastMessage = {
      event: 'chat',
      data: {
        sender: client.userId, // Or look up username from a cache
        message: data.message,
      },
    };

    const messageString = JSON.stringify(broadcastMessage);
    
    // Broadcast to all clients
    this.server.clients.forEach((c) => {
      if (c.readyState === WebSocket.OPEN) {
        c.send(messageString);
      }
    });
  }
}
