Class iris.src.demo.msg.ImportRow Extends %RegisteredObject
{
Property SourceFile As %String;
Property RowNum     As %Integer;
Property OrderId    As %String(MAXLEN=64);
Property CustomerId As %String(MAXLEN=64);
Property Amount     As %Decimal(SCALE=2, PRECISION=12);
Property Currency   As %String(MAXLEN=8);
Property OrderDate  As %Date;
Property IdemKey    As %String(MAXLEN=128);
}
