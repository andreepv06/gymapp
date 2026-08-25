import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class UpsertExerciseNoteDto {
  @ApiProperty({ example: 'Tenere i gomiti stretti' })
  @IsString()
  @MinLength(1)
  note: string;
}