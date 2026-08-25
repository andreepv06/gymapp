import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

export class SetCompletionDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  completed: boolean;
}