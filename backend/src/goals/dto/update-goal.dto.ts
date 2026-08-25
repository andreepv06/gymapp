import { ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';
import { CreateGoalDto } from './create-goal.dto';

export class UpdateGoalDto extends PartialType(CreateGoalDto) {
  @ApiPropertyOptional({ example: 'active', description: "'active' | 'paused' | 'archived'" })
  @IsOptional()
  @IsString()
  status?: string;
}