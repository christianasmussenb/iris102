/// DEPRECATED: Simple variant retained only for reference; not used by the Production.
/// Renamed to avoid class name conflicts with the active Demo.Postgres.Operation.
Class Demo.Postgres.OperationSimpleDeprecated Extends Ens.BusinessOperation
{

/// SQL Adapter for database connections
Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";

/// PostgreSQL Connection Settings configured via adapter settings
Property PostgreSQLHost As %String [ InitialExpression = "localhost" ];

Property PostgreSQLPort As %String [ InitialExpression = "5432" ];

Property PostgreSQLDatabase As %String [ InitialExpression = "demo" ];

Property PostgreSQLCredentials As %String [ InitialExpression = "PostgreSQL-Demo-Credentials" ];

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
        Set pResponse.DatabaseType = "PostgreSQL"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        Set pResponse.RecordsInserted = 0
        Set pResponse.RecordsFailed = 0
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        Set pResponse.Status = "processing"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Starting PostgreSQL insertion for " _ pRequest.TotalRecords _ " records")
        
        // Validate request
        If pRequest.TotalRecords = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "No records to process"
            Return $$$OK
        }
        
        // Process records with simulated database insertions
        Set totalInserted = 0
        Set totalFailed = 0
        
        For i=1:1:pRequest.TotalRecords {
            Set csvLine = pRequest.CSVRecords.GetAt(i)
            If csvLine '= "" {
                // Parse and simulate insertion
                Set insertStatus = ..InsertCSVRecord(csvLine, pRequest.FileName, pRequest.FileHash)
                If $$$ISOK(insertStatus) {
                    Set totalInserted = totalInserted + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Simulated PostgreSQL insert record " _ i _ ": " _ csvLine)
                } Else {
                    Set totalFailed = totalFailed + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Failed simulation record " _ i _ ": " _ csvLine _ " - " _ $System.Status.GetErrorText(insertStatus))
                }
            }
        }
        
        Set pResponse.RecordsInserted = totalInserted
        Set pResponse.RecordsFailed = totalFailed
        Set pResponse.Status = "completed"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "PostgreSQL operation completed: " _ totalInserted _ " processed, " _ totalFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "PostgreSQL operation exception: " _ ex.DisplayString()
        
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Exception during PostgreSQL operation: " _ ex.DisplayString())
    }
    
    Return status
}

/// Insert a CSV record into PostgreSQL database (simulated for demo)
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
        
        // Execute real PostgreSQL insertion
        Set sql = "INSERT INTO csv_records (csv_id, name, age, city, source_file, file_hash) VALUES (?, ?, ?, ?, ?, ?)"
        Set stmt = ..Adapter.CreateStatement()
        Set result = stmt.%Execute(csvId, name, age, city, fileName, fileHash)
        
        If result.%SQLCODE < 0 {
            Return $$$ERROR($$$EnsErrGeneral, "PostgreSQL insertion failed: " _ result.%Message)
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "PostgreSQL Insert SUCCESS: " _ csvId _ "," _ name _ "," _ age _ "," _ city _ " from " _ fileName)
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Test PostgreSQL connection (simulated for demo)
Method TestConnection() As %Status
{
    Set status = $$$OK
    
    Try {
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Simulating PostgreSQL connection test...")
        
        // Simulate successful connection test
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "SIMULATED PostgreSQL connection test successful")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "PostgreSQL connection test exception: " _ ex.DisplayString())
    }
    
    Return status
}

}