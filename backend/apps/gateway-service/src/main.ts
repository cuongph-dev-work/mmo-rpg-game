import { NestFactory } from '@nestjs/core';
import { WsAdapter } from '@nestjs/platform-ws';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useWebSocketAdapter(new WsAdapter(app));
  await app.listen(process.env.GATEWAY_PORT || 3002);
  console.log(`Gateway Service running on port ${process.env.GATEWAY_PORT || 3002}`);
}
bootstrap();
