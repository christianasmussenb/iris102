/// Demo.Msg.DBOperationRequest - Request message for database operations
Class Demo.Msg.DBOperationRequest Extends Ens.Request
{

/// Type of operation: "INSERT", "UPSERT"
Property Operation As %String(MAXLEN = 20) [ Required ];

/// Records to process (array of CSV rows)
Property Records As list Of Demo.Msg.CSVRecord;

/// Source file information for logging
Property SourceFile As %String(MAXLEN = 255);

/// File hash for logging
Property FileHash As %String(MAXLEN = 64);

/// Storage definition
Storage Default
{
<Data name="DBOperationRequestDefaultData">
<Subscript>"DBOperationRequest"</Subscript>
<Value name="1">
<Value>Operation</Value>
</Value>
<Value name="2">
<Value>Records</Value>
</Value>
<Value name="3">
<Value>SourceFile</Value>
</Value>
<Value name="4">
<Value>FileHash</Value>
</Value>
</Data>
<DataLocation>^Demo.Msg.DBOperationRequestD</DataLocation>
<DefaultData>DBOperationRequestDefaultData</DefaultData>
<IdLocation>^Demo.Msg.DBOperationRequestD</IdLocation>
<IndexLocation>^Demo.Msg.DBOperationRequestI</IndexLocation>
<StreamLocation>^Demo.Msg.DBOperationRequestS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}