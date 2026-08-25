import { PartialType, OmitType } from '@nestjs/swagger';
import { CreateWorkoutExerciseDto } from './create-workout-exercise.dto';

// exerciseId non è modificabile dopo la creazione (coerente con V1:
// per cambiare esercizio si rimuove/ricrea la riga, non la si muta).
export class UpdateWorkoutExerciseDto extends PartialType(
  OmitType(CreateWorkoutExerciseDto, ['exerciseId'] as const),
) {}