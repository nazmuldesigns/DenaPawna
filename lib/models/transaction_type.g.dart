// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 1;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.lent;
      case 1:
        return TransactionType.borrowed;
      case 2:
        return TransactionType.receivedPayment;
      case 3:
        return TransactionType.givenPayment;
      default:
        return TransactionType.lent;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.lent:
        writer.writeByte(0);
        break;
      case TransactionType.borrowed:
        writer.writeByte(1);
        break;
      case TransactionType.receivedPayment:
        writer.writeByte(2);
        break;
      case TransactionType.givenPayment:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
