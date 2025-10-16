/// Demo.Installer - Installation and setup class for iris102 demo
Class Demo.Installer Extends %RegisteredObject
{
 

/// Main installation method
ClassMethod Run() As %Status
{
    Set status = 1
    
    Try {
        Write "Starting iris102 demo installation...",!
        
        // Import all source files
    Set status = ..ImportSources()
    If $SYSTEM.Status.IsError(status) Quit
        
        // Compile all classes
    Set status = ..CompileAll()
    If $SYSTEM.Status.IsError(status) Quit
        
        // Create SQL Gateway connections (JDBC) so they appear in the Portal
        Set status = ..SetupSQLGateway()
        If $SYSTEM.Status.IsError(status) Quit

        // Create and configure the Production
    Set status = ..SetupProduction()
    If $SYSTEM.Status.IsError(status) Quit
        
        Write "Installation completed successfully!",!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "Installation failed: "
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Create or update SQL Gateway connections for JDBC (MySQL, PostgreSQL)
ClassMethod SetupSQLGateway() As %Status
{
    Set status = 1
    Try {
        Write "Setting up SQL Gateway connections (JDBC)...",!

        // Ensure we are in %SYS to manage Config classes
        Set oldNs = $namespace
        If oldNs '= "%SYS" {
            zn "%SYS"
        }

        // Read environment / defaults
        Set javaHome = $System.Util.GetEnviron("JAVA_HOME", "/usr/lib/jvm/java-11-openjdk-amd64")
        Set mysqlHost = $System.Util.GetEnviron("MYSQL_HOST", "mysql")
        Set mysqlPort = +$System.Util.GetEnviron("MYSQL_PORT", 3306)
        Set pgHost = $System.Util.GetEnviron("PG_HOST", "postgres")
        Set pgPort = +$System.Util.GetEnviron("PG_PORT", 5432)

        // Classpaths inside the container
        Set mysqlJar = "/opt/irisapp/jdbc/mariadb-java-client.jar"
        Set pgJar = "/opt/irisapp/jdbc/postgresql.jar"

        // Create or update JDBC-MySQL
        Do ..EnsureGateway("JDBC-MySQL", "JDBC", mysqlHost, mysqlPort, mysqlJar, javaHome)

        // Create or update JDBC-PostgreSQL
        Do ..EnsureGateway("JDBC-PostgreSQL", "JDBC", pgHost, pgPort, pgJar, javaHome)

        Write "SQL Gateway setup complete.",!

        // Restore previous namespace
        If $namespace '= oldNs {
            zn oldNs
        }

    } Catch ex {
        Set status = ex.AsStatus()
        Write "Error setting up SQL Gateway: "
        Do $System.Status.DisplayError(status)
    }
    Return status
}

/// Idempotent helper: create or update a Config.Gateways entry
ClassMethod EnsureGateway(name As %String, type As %String, address As %String, port As %Integer, classPath As %String, javaHome As %String = "") As %Status
{
    // Initialize locals
    Set status = 1, sc = 1
    Try {
        // Try to get existing gateway into local array
        Set sc = ##class(Config.Gateways).Get(name, .gw)
        If '$SYSTEM.Status.IsError(sc) {
            // Update existing
            Set gw("Name") = name
            Set gw("Type") = type
            If classPath'="" Set gw("ClassPath") = classPath
            If javaHome'="" Set gw("JavaHome") = javaHome
            If address'="" Set gw("Address") = address
            If +port>0 Set gw("Port") = +port
            Set sc = ##class(Config.Gateways).Modify(name, .gw)
            If $SYSTEM.Status.IsError(sc) Return sc
            Return sc
        }

        // Create new if not found
        Set obj = ##class(Config.Gateways).%New()
        Set obj.Name = name
        Set obj.Type = type
        If classPath'="" Set obj.ClassPath = classPath
        If javaHome'="" Set obj.JavaHome = javaHome
        If address'="" Set obj.Address = address
        If +port>0 Set obj.Port = +port
        Set sc = obj.%Save()
        Return sc

    } Catch ex {
        Set status = ex.AsStatus()
    }
    Return status
}

/// Import all source files from /opt/irisapp/src
ClassMethod ImportSources() As %Status
{
    Set status = 1
    
    Try {
        Write "Importing source files...",!
        
        // Import all .cls files recursively
    Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.cls", "ckr", .errors, 1)
    If $SYSTEM.Status.IsError(status) {
            Write "Error importing classes:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        // Import all .bpl files recursively  
    Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.bpl", "ckr", .errors, 1)
    If $SYSTEM.Status.IsError(status) {
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
    Set status = 1
    
    Try {
        Write "Compiling all classes...",!
        
    Set status = $system.OBJ.CompileAll("ckr")
    If $SYSTEM.Status.IsError(status) {
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
    Set status = 1
    
    Try {
        Write "Setting up Production...",!
        
        // Stop any existing production
    Set status = ##class(Ens.Director).StopProduction(, 1)
    If $SYSTEM.Status.IsError(status) && (..IsProductionNotRunningError(status)=0) {
            Write "Error stopping existing production:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        // Wait a moment
        Hang 2
        
        // Start the new production
        Set productionName = "Demo.Production"
    Set status = ##class(Ens.Director).StartProduction(productionName)
    If $SYSTEM.Status.IsError(status) {
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
    Set status = 1
    
    Try {
        Write "=== Installation Status Check ===",!
        
        // Check if classes exist
        If ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Production") {
            Write "✓ Demo.Production class exists",!
        } Else {
            Write "✗ Demo.Production class missing",!
            // leaving status as-is (non-error)
        }
        
        If ##class(%Dictionary.ClassDefinition).%ExistsId("Demo.FileService") {
            Write "✓ Demo.FileService class exists",!
        } Else {
            Write "✗ Demo.FileService class missing",!
            // leaving status as-is (non-error)
        }
        
        // Check production status (avoid undefined macros)
        Set productionStatus = ##class(Ens.Director).GetProductionStatus(.productionName, .state)
        Set isRunning = ##class(Ens.Director).IsProductionRunning(productionName)
        If isRunning {
            Write "✓ Production "_productionName_" is running",!
        } Else {
            Write "✗ Production not running or error",!
            If $SYSTEM.Status.IsError(productionStatus) {
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