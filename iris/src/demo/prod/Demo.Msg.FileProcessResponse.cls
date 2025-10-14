/// Demo.Msg.FileProcessResponse - Response message from CSV file processing
Class Demo.Msg.FileProcessResponse Extends Ens.Response
{

/// Processing status: "ok", "partial", "error", "duplicate"
Property Status As %String(MAXLEN = 20) [ Required ];

/// Total number of records found in CSV
Property TotalRecords As %Integer;

/// Number of records successfully inserted in MySQL
Property MySQLRecordsOK As %Integer;

/// Number of records that failed to insert in MySQL
Property MySQLRecordsFailed As %Integer;

/// Number of records successfully inserted in PostgreSQL
Property PostgreSQLRecordsOK As %Integer;

/// Number of records that failed to insert in PostgreSQL
Property PostgreSQLRecordsFailed As %Integer;

/// Error message if processing failed
Property ErrorMessage As %String(MAXLEN = 2000);

/// Array of detailed error messages per record
Property DetailedErrors As list Of %String(MAXLEN = 500);

/// Processing start time
Property ProcessingStarted As %TimeStamp;

/// Processing end time
Property ProcessingCompleted As %TimeStamp;

/// Duration in seconds
Property ProcessingDuration As %Numeric(SCALE = 3);

/// Method to calculate processing duration
Method CalculateDuration() As %Numeric
{
    If (..ProcessingStarted '= "") && (..ProcessingCompleted '= "") {
        Set start = ##class(%TimeStamp).LogicalToOdbc(..ProcessingStarted)
        Set end = ##class(%TimeStamp).LogicalToOdbc(..ProcessingCompleted)
        Set ..ProcessingDuration = ##class(%TimeStamp).TimestampSubtract(end, start)
    }
    Return ..ProcessingDuration
}

/// Method to add detailed error
Method AddDetailedError(error As %String)
{
    Do ..DetailedErrors.Insert(error)
}

/// Storage definition
Storage Default
{
<Data name="FileProcessResponseDefaultData">
<Subscript>"FileProcessResponse"</Subscript>
<Value name="1">
<Value>Status</Value>
</Value>
<Value name="2">
<Value>TotalRecords</Value>
</Value>
<Value name="3">
<Value>MySQLRecordsOK</Value>
</Value>
<Value name="4">
<Value>MySQLRecordsFailed</Value>
</Value>
<Value name="5">
<Value>PostgreSQLRecordsOK</Value>
</Value>
<Value name="6">
<Value>PostgreSQLRecordsFailed</Value>
</Value>
<Value name="7">
<Value>ErrorMessage</Value>
</Value>
<Value name="8">
<Value>DetailedErrors</Value>
</Value>
<Value name="9">
<Value>ProcessingStarted</Value>
</Value>
<Value name="10">
<Value>ProcessingCompleted</Value>
</Value>
<Value name="11">
<Value>ProcessingDuration</Value>
</Value>
</Data>
<DataLocation>^Demo.Msg.FileProcessResponseD</DataLocation>
<DefaultData>FileProcessResponseDefaultData</DefaultData>
<IdLocation>^Demo.Msg.FileProcessResponseD</IdLocation>
<IndexLocation>^Demo.Msg.FileProcessResponseI</IndexLocation>
<StreamLocation>^Demo.Msg.FileProcessResponseS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}