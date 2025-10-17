/// Demo.MySQL.Operation - Business Operation for MySQL database insertions
Class Demo.MySQL.Operation Extends Ens.BusinessOperation
{

/// SQL Adapter for database connections
Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";
/// Simple ODBC connection test using a temporary adapter instance
ClassMethod TestConnection() As %Status
{
    Set sc = $$$OK
    Try {
        Set adapter = ##class(EnsLib.SQL.OutboundAdapter).%New()
        Set adapter.DSN = "MySQL-Demo"
        // Credentials are embedded in DSN, no need to set separately
        Do adapter.Connect()
        Do ##class(Demo.Util.Logger).WriteEvent("INFO","Demo.MySQL.Operation","ODBC connect OK to DSN MySQL-Demo")
        Do adapter.Disconnect()
    } Catch ex {
        Set sc = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR","Demo.MySQL.Operation","ODBC connect failed: " _ ex.DisplayString())
    }
    Quit sc
}

/// MySQL Connection Settings configured via adapter settings
Property MySQLHost As %String [ InitialExpression = "localhost" ];

Property MySQLPort As %String [ InitialExpression = "3306" ];

Property MySQLDatabase As %String [ InitialExpression = "demo" ];

/// Handle database operation requests
Method OnMessage(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Return ..ProcessDatabaseInsert(pRequest, .pResponse)
}

/// Process database insert request with real SQL connections
Method ProcessDatabaseInsert(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Set status = $$$OK
    Set pResponse = ##class(Demo.Msg.DatabaseInsertResponse).%New()
    
    Try {
        // Initialize response
        Set pResponse.DatabaseType = "MySQL"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        Set pResponse.RecordsInserted = 0
        Set pResponse.RecordsFailed = 0
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        Set pResponse.Status = "processing"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Starting MySQL insertion for " _ pRequest.TotalRecords _ " records")
        
        // Validate request
        If pRequest.TotalRecords = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "No records to process"
            Return $$$OK
        }
        
        // Process records with real database insertions
        Set totalInserted = 0
        Set totalFailed = 0
        
        For i=1:1:pRequest.TotalRecords {
            Set csvLine = pRequest.CSVRecords.GetAt(i)
            If csvLine '= "" {
                // Parse and insert record
                Set insertStatus = ..InsertCSVRecord(csvLine, pRequest.FileName, pRequest.FileHash)
                If $$$ISOK(insertStatus) {
                    Set totalInserted = totalInserted + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Inserted record " _ i _ ": " _ csvLine)
                } Else {
                    Set totalFailed = totalFailed + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Failed to insert record " _ i _ ": " _ csvLine _ " - " _ $System.Status.GetErrorText(insertStatus))
                }
            }
        }
        
        Set pResponse.RecordsInserted = totalInserted
        Set pResponse.RecordsFailed = totalFailed
        Set pResponse.Status = "completed"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL operation completed: " _ totalInserted _ " processed, " _ totalFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "MySQL operation exception: " _ ex.DisplayString()
        
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Exception during MySQL operation: " _ ex.DisplayString())
    }
    
    Return status
}

/// Insert a CSV record into MySQL database (simulated for demo)
Method InsertCSVRecord(csvLine As %String, fileName As %String, fileHash As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Parse CSV line (expecting: id,name,age,city)
        Set fields = $ListFromString(csvLine, ",")
        If $ListLength(fields) < 4 {
            Return $$$ERROR($$$EnsErrGeneral, "Invalid CSV format - expected 4 fields")
        }
        
        Set csvId = $ZStrip($List(fields, 1), "<>W""'")
        Set name = $ZStrip($List(fields, 2), "<>W""'")
        Set age = $ZStrip($List(fields, 3), "<>W""'")
        Set city = $ZStrip($List(fields, 4), "<>W""'")
        
        // Validate data
        If 'csvId || 'name || 'age || 'city {
            Return $$$ERROR($$$EnsErrGeneral, "Invalid data - empty required fields")
        }
        
        If '$IsValidNum(age) {
            Return $$$ERROR($$$EnsErrGeneral, "Invalid age value: " _ age)
        }
        
        // Execute real MySQL insertion
        Set sql = "INSERT INTO csv_records (csv_id, name, age, city, source_file, file_hash) VALUES (?, ?, ?, ?, ?, ?)"
        Set stmt = ..Adapter.CreateStatement()
        Set result = stmt.%Execute(csvId, name, age, city, fileName, fileHash)
        
        If result.%SQLCODE < 0 {
            Return $$$ERROR($$$EnsErrGeneral, "MySQL insertion failed: " _ result.%Message)
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL Insert SUCCESS: " _ csvId _ "," _ name _ "," _ age _ "," _ city _ " from " _ fileName)
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

// ...existing code...

/// Get operation statistics
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Operation: Demo.MySQL.Operation (Simple)" _ $C(13,10)
        Set stats = stats _ "MySQL Host: " _ ..MySQLHost _ ":" _ ..MySQLPort _ $C(13,10)
        Set stats = stats _ "MySQL Database: " _ ..MySQLDatabase _ $C(13,10)
        Set stats = stats _ "Credentials: " _ ..MySQLCredentials _ $C(13,10)
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}