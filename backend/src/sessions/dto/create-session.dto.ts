import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateSessionDto {
  @ApiPropertyOptional({ description: 'Id di una scheda propria, opzionale' })
  @IsOptional()
  @IsString()
  workoutId?: string;

  @ApiProperty({ example: 'Push Day' })
  @IsString()
  @MinLength(1)
  workoutName: string;

  @ApiProperty({ example: '2026-08-24T18:00:00.000Z' })
  @IsDateString()
  date: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  durationSeconds?: number;
}