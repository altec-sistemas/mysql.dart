import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql_dart/mysql_protocol.dart';
import 'package:mysql_dart/exception.dart';
import '../column_utils.dart';

class MySQLBinaryResultSetRowPacket extends MySQLPacketPayload {
  final List<dynamic> values;

  MySQLBinaryResultSetRowPacket({
    required this.values,
  });

  factory MySQLBinaryResultSetRowPacket.decode(
    Uint8List buffer,
    List<MySQLColumnDefinitionPacket> colDefs,
  ) {
    final byteData = ByteData.sublistView(buffer);
    int offset = 0;

    final type = byteData.getUint8(offset);
    offset += 1;
    if (type != 0) {
      throw MySQLProtocolException(
        "Cannot decode MySQLBinaryResultSetRowPacket: packet type is not 0x00",
      );
    }

    List<dynamic> values = [];

    int nullBitmapSize = ((colDefs.length + 9) / 8).floor();

    final nullBitmap = Uint8List.sublistView(
      buffer,
      offset,
      offset + nullBitmapSize,
    );
    offset += nullBitmapSize;

    for (int x = 0; x < colDefs.length; x++) {
      final bitmapByteIndex = ((x + 2) / 8).floor();
      final bitmapBitIndex = (x + 2) % 8;
      final byteToCheck = nullBitmap[bitmapByteIndex];
      final isNull = (byteToCheck & (1 << bitmapBitIndex)) != 0;

      if (isNull) {
        values.add(null);
      } else {
        final isUnsigned = (colDefs[x].flags & 0x0020) != 0;

        final parseResult = parseBinaryColumnData(
          colDefs[x].type.intVal,
          byteData,
          buffer,
          offset,
          isUnsigned: isUnsigned,
        );

        offset += parseResult.item2;
        var value = parseResult.item1;

        if (value is Uint8List && columnShouldBeTextual(colDefs[x])) {
          value = utf8.decode(value, allowMalformed: true);
        }
        values.add(value);
      }
    }

    return MySQLBinaryResultSetRowPacket(
      values: values,
    );
  }

  @override
  Uint8List encode() {
    throw UnimplementedError("Encode not implemented for MySQLBinaryResultSetRowPacket");
  }
}
