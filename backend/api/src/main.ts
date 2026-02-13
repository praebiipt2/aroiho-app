import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors();
  app.useGlobalPipes(new ValidationPipe());

  const port = process.env.PORT || 3000;

  // ⭐ สำคัญมากสำหรับ Docker
  await app.listen(port, '0.0.0.0');

  console.log(`🚀 Server running on port ${port}`);
}
bootstrap();