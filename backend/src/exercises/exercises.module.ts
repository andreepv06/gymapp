import { Module } from '@nestjs/common';
import { ExercisesController } from './exercises.controller';
import { ExercisesService } from './exercises.service';
import { ExerciseNotesController } from './exercise-notes.controller';
import { ExerciseNotesService } from './exercise-notes.service';

@Module({
  controllers: [ExercisesController, ExerciseNotesController],
  providers: [ExercisesService, ExerciseNotesService],
})
export class ExercisesModule {}