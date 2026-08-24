import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreateExerciseDto {
  @ApiProperty({ example: 'Panca piana' })
  @IsString()
  @MinLength(1)
  name: string;

  @ApiProperty({ example: 'Petto' })
  @IsString()
  muscleGroup: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}