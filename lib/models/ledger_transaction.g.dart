// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LedgerTransactionAdapter extends TypeAdapter<LedgerTransaction> {
  @override
  final int typeId = 2;

  @override
  LedgerTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LedgerTransaction(
      id: fields[0] as String,
      personId: fields[1] as String,
      type: fields[2] as TransactionType,
      amountPaisa: fields[3] as int,
      date: fields[4] as DateTime,
      note: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      isDeleted: fields[8] as bool,
      idempotencyKey: fields[9] as String?,
      isSettlement: fields[10] as bool,
      paymentMethod: fields[11] as String? ?? 'cash',
    );
  }

  @override
  void write(BinaryWriter writer, LedgerTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amountPaisa)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isDeleted)
      ..writeByte(9)
      ..write(obj.idempotencyKey)
      ..writeByte(10)
      ..write(obj.isSettlement)
      ..writeByte(11)
      ..write(obj.paymentMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
