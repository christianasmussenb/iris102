/// Demo.Msg.DatabaseInsertRequest - Request message for database insertions
Class Demo.Msg.DatabaseInsertRequest Extends Ens.Request
{

/// Database type (MySQL or PostgreSQL)
Property DatabaseType As %String(MAXLEN = 50) [ Required ];

/// Unique request identifier for tracking
Property RequestId As %String(MAXLEN = 64) [ Required ];

/// Total number of records to insert
Property TotalRecords As %Integer [ Required ];

/// CSV header line (if present)
Property CSVHeader As %String(MAXLEN = 2000);

/// Collection of CSV data lines
Property CSVRecords As %ArrayOfDataTypes [ Required ];

/// Source file name
Property FileName As %String(MAXLEN = 255);

/// File hash for tracking
Property FileHash As %String(MAXLEN = 64);

/// Timestamp when request was submitted
Property SubmittedAt As %TimeStamp [ Required ];

/// Method to initialize the request
Method %OnNew() As %Status
{
    Set ..CSVRecords = ##class(%ArrayOfDataTypes).%New()
    Return $$$OK
}

/// Method to add a CSV record
Method AddCSVRecord(lineNumber As %Integer, csvLine As %String) As %Status
{
    Do ..CSVRecords.SetAt(csvLine, lineNumber)
    Return $$$OK
}

/// Method to get record count
Method GetRecordCount() As %Integer
{
    Return ..CSVRecords.Count()
}

/// Storage definition
Storage Default
{
<Data name="DatabaseInsertRequestDefaultData">
<Subscript>"DatabaseInsertRequest"</Subscript>
<Value name="1">
<Value>DatabaseType</Value>
</Value>
<Value name="2">
<Value>RequestId</Value>
</Value>
<Value name="3">
<Value>TotalRecords</Value>
</Value>
<Value name="4">
<Value>CSVHeader</Value>
</Value>
<Value name="5">
<Value>CSVRecords</Value>
</Value>
<Value name="6">
<Value>SubmittedAt</Value>
</Value>
</Data>
<DataLocation>^Ens.MessageBodyD</DataLocation>
<DefaultData>DatabaseInsertRequestDefaultData</DefaultData>
<IdLocation>^Ens.MessageBodyD</IdLocation>
<IndexLocation>^Ens.MessageBodyI</IndexLocation>
<StreamLocation>^Ens.MessageBodyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}