import { Module } from '@nestjs/common';
import { TrainingModesController } from './training-modes.controller';
import { TrainingModesService } from './training-modes.service';

@Module({
  controllers: [TrainingModesController],
  providers: [TrainingModesService],
  exports: [TrainingModesService],
})
export class TrainingModesModule {}