import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMinSize,
  IsArray,
  IsOptional,
  IsString,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { TrainingModeSetDto } from './training-mode-set.dto';

export class CreateTrainingModeDto {
  @ApiProperty({ example: '3×8' })
  @IsString()
  @MinLength(1)
  name: string;

  @ApiProperty({ example: 'fixed', description: "'fixed' | 'range' | 'pyramid' | 'custom' | 'other'" })
  @IsString()
  category: string;

  @ApiProperty({ type: [TrainingModeSetDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TrainingModeSetDto)
  sets: TrainingModeSetDto[];
}