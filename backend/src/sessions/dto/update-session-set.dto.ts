import { PartialType, OmitType } from '@nestjs/swagger';
import { CreateSessionSetDto } from './create-session-set.dto';

export class UpdateSessionSetDto extends PartialType(
  OmitType(CreateSessionSetDto, ['exerciseId', 'setNumber'] as const),
) {}