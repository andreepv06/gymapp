import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateSportSessionDto {
  @ApiProperty({ example: 'running', description: "'running' | 'cycling' | 'swimming' | 'walking' | 'hiking'" })
  @IsString()
  sportType: string;

  @ApiProperty({ example: '2026-08-24T18:00:00.000Z' })
  @IsDateString()
  date: string;

  @ApiProperty({ example: 1800 })
  @IsInt()
  @Min(1)
  durationSeconds: number;

  @ApiPropertyOptional({ example: 5.2 })
  @IsOptional()
  @IsNumber()
  distanceKm?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}