import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateWorkoutDto {
  @ApiProperty({ example: 'Push Day' })
  @IsString()
  @MinLength(1)
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  iconId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  iconColorIndex?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  customImageUrl?: string;
}