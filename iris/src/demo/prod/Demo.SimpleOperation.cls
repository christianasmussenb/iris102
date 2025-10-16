/// Demo.SimpleOperation - Simple message handler for testing database simulation
Class Demo.SimpleOperation Extends %RegisteredObject
{

/// Handle database insert request
ClassMethod HandleInsertRequest(pRequest As Demo.Msg.DatabaseInsertRequest) As Demo.Msg.DatabaseInsertResponse
{
    Set pResponse = ##class(Demo.Msg.DatabaseInsertResponse).%New()
    
    Try {
        // Initialize response
        Set pResponse.DatabaseType = "Simulated"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        Set pResponse.RecordsInserted = 0
        Set pResponse.RecordsFailed = 0
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        Set pResponse.Status = "processing"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.SimpleOperation", "Starting simulated insertion for " _ pRequest.TotalRecords _ " records")
        
        // Validate request
        If pRequest.TotalRecords = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "No records to process"
            Return pResponse
        }
        
        // Process records with simulation
        Set totalInserted = 0
        Set totalFailed = 0
        
        For i=1:1:pRequest.TotalRecords {
            Set csvLine = pRequest.CSVRecords.GetAt(i)
            If csvLine '= "" {
                // Parse and simulate insertion
                Set insertStatus = ..SimulateInsertCSVRecord(csvLine, pRequest.FileName, pRequest.FileHash)
                If $$$ISOK(insertStatus) {
                    Set totalInserted = totalInserted + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.SimpleOperation", "Simulated insert record " _ i _ ": " _ csvLine)
                } Else {
                    Set totalFailed = totalFailed + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.SimpleOperation", "Failed simulation record " _ i _ ": " _ csvLine _ " - " _ $System.Status.GetErrorText(insertStatus))
                }
            }
        }
        
        // Set final response
        Set pResponse.RecordsInserted = totalInserted
        Set pResponse.RecordsFailed = totalFailed
        
        If totalFailed = 0 {
            Set pResponse.Status = "ok"
        } ElseIf totalInserted > 0 {
            Set pResponse.Status = "partial"
            Set pResponse.ErrorMessage = "Some records failed: " _ totalFailed _ " out of " _ pRequest.TotalRecords
        } Else {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "All records failed"
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.SimpleOperation", "Simulation completed: " _ totalInserted _ " inserted, " _ totalFailed _ " failed")
        
    } Catch ex {
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "Simulation exception: " _ ex.DisplayString()
        
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.SimpleOperation", "Exception during simulation: " _ ex.DisplayString())
    }
    
    Return pResponse
}

/// Simulate CSV record insertion
ClassMethod SimulateInsertCSVRecord(csvLine As %String, fileName As %String, fileHash As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Parse CSV line (expecting: id,name,age,city)
        Set fields = $ListFromString(csvLine, ",")
        If $ListLength(fields) < 4 {
            Set status = $$$ERROR(5001, "Invalid CSV format - expected 4 fields")
            Quit
        }
        
        Set csvId = $ZStrip($List(fields, 1), "<>W""'")
        Set name = $ZStrip($List(fields, 2), "<>W""'")
        Set age = $ZStrip($List(fields, 3), "<>W""'")
        Set city = $ZStrip($List(fields, 4), "<>W""'")
        
        // Validate data
        If csvId = "" || name = "" || age = "" || city = "" {
            Set status = $$$ERROR(5002, "Invalid data - empty required fields")
            Quit
        }
        
        If '$IsValidNum(age) {
            Set status = $$$ERROR(5003, "Invalid age value: " _ age)
            Quit
        }
        
        // Simulate successful insertion
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.SimpleOperation", "SIMULATED Insert: " _ csvId _ "," _ name _ "," _ age _ "," _ city _ " from " _ fileName)
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

}