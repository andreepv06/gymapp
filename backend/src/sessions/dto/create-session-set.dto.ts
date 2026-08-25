import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateSessionSetDto {
  @ApiProperty()
  @IsString()
  exerciseId: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  trainingModeId?: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  setNumber: number;

  @ApiProperty({ example: 70 })
  @IsNumber()
  weight: number;

  @ApiProperty({ example: 8 })
  @IsInt()
  reps: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  completed?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  restSeconds?: number;

  @ApiPropertyOptional({ description: "'standard' | 'partial' | 'custom'" })
  @IsOptional()
  @IsString()
  executionStatus?: string;
}