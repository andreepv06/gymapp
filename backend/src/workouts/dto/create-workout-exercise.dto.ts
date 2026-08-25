import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateWorkoutExerciseDto {
  @ApiProperty()
  @IsString()
  exerciseId: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  circuitId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  trainingModeId?: string;

  @ApiPropertyOptional({ default: 3 })
  @IsOptional()
  @IsInt()
  @Min(1)
  sets?: number;

  @ApiPropertyOptional({ default: 8 })
  @IsOptional()
  @IsInt()
  @Min(1)
  targetReps?: number;

  @ApiPropertyOptional()
  @IsOptional()
  targetWeight?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  restSeconds?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  sortOrder?: number;
}