/// Demo.Installer - Installation and setup class for iris102 demo
Class Demo.Installer Extends %RegisteredObject
{

/// Main installation method
ClassMethod Run() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Starting iris102 demo installation...",!
        
        // Import all source files
        Set status = ..ImportSources()
        If $$$ISERR(status) Quit
        
        // Compile all classes
        Set status = ..CompileAll()
        If $$$ISERR(status) Quit
        
        // Create and configure the Production
        Set status = ..SetupProduction()
        If $$$ISERR(status) Quit
        
        Write "Installation completed successfully!",!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "Installation failed: "
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Import all source files from /opt/irisapp/src
ClassMethod ImportSources() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Importing source files...",!
        
        // Import all .cls files recursively
        Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.cls", "ckr", .errors, 1)
        If $$$ISERR(status) {
            Write "Error importing classes:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        // Import all .bpl files recursively  
        Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.bpl", "ckr", .errors, 1)
        If $$$ISERR(status) {
            Write "Error importing BPL files:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "Source files imported successfully!",!
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Compile all imported classes
ClassMethod CompileAll() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Compiling all classes...",!
        
        Set status = $system.OBJ.CompileAll("ckr")
        If $$$ISERR(status) {
            Write "Error compiling classes:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "All classes compiled successfully!",!
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Setup and start the Production
ClassMethod SetupProduction() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Setting up Production...",!
        
        // Stop any existing production
        Set status = ##class(Ens.Director).StopProduction(, 1)
        If $$$ISERR(status) && '..IsProductionNotRunningError(status) {
            Write "Error stopping existing production:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        // Wait a moment
        Hang 2
        
        // Start the new production
        Set productionName = "Demo.Production"
        Set status = ##class(Ens.Director).StartProduction(productionName)
        If $$$ISERR(status) {
            Write "Error starting production:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "Production "_productionName_" started successfully!",!
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Check if error is "production not running" which is expected
ClassMethod IsProductionNotRunningError(status As %Status) As %Boolean
{
    Set text = $System.Status.GetErrorText(status)
    Return $Find(text, "not running") > 0
}

/// Utility method to check installation status
ClassMethod CheckStatus() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "=== Installation Status Check ===",!
        
        // Check if classes exist
        If ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Production") {
            Write "✓ Demo.Production class exists",!
        } Else {
            Write "✗ Demo.Production class missing",!
            Set status = $$$ERROR(5001, "Demo.Production class missing")
        }
        
        If ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.FileService") {
            Write "✓ Demo.FileService class exists",!
        } Else {
            Write "✗ Demo.FileService class missing",!
            Set status = $$$ERROR(5001, "Demo.FileService class missing")
        }
        
        // Check production status
        Set productionStatus = ##class(Ens.Director).GetProductionStatus(.productionName, .state)
        If $$$ISOK(productionStatus) && (state = $$$eProductionStateRunning) {
            Write "✓ Production "_productionName_" is running",!
        } Else {
            Write "✗ Production not running or error",!
            If $$$ISERR(productionStatus) {
                Do $System.Status.DisplayError(productionStatus)
            }
        }
        
        Write "=== End Status Check ===",!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "Error checking status: "
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

}