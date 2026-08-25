import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

export class CreateGoalDto {
  @ApiProperty({ example: 'Bere 2L di acqua' })
  @IsString()
  @MinLength(1)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 'Salute' })
  @IsString()
  category: string;

  @ApiProperty({
    example: 'daily',
    description:
      "'daily' | 'specificDays' | 'weekend' | 'weekdays' | 'dateRange' | 'customInterval'",
  })
  @IsString()
  scheduleType: string;

  @ApiPropertyOptional({ example: [1, 3, 5], description: '1=Lunedì..7=Domenica' })
  @IsOptional()
  @IsArray()
  scheduleDaysOfWeek?: number[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  scheduleStartDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  scheduleEndDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  scheduleCustomInterval?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  deadlineDate?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  colorIndex?: number;
}