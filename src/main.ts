import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

const PORT = 3000;

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  console.log('Server running on port:', PORT);
  app.enableShutdownHooks();
  await app.listen(PORT);
}
bootstrap().catch(console.error);
