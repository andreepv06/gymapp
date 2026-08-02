// Router per import condizionale — identico al pattern di image_picker_helper.dart
export 'backup_file_web.dart'
    if (dart.library.io) 'backup_file_stub.dart';