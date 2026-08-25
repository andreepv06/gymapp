import { PartialType } from '@nestjs/swagger';
import { CreateSportSessionDto } from './create-sport-session.dto';

export class UpdateSportSessionDto extends PartialType(CreateSportSessionDto) {}