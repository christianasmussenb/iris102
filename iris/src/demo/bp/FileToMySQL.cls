Class iris.src.demo.bp.FileToMySQL Extends %RegisteredObject
{

XData BPL
{
<process language='objectscript' request='EnsLib.RecordMap.Record' response='Ens.Response'>
  <context>
    <property name='Row' type='DEMO.msg.ImportRow'/>
  </context>

  <transform name='MapRow' language='objectscript' target='context.Row' transform='DEMO.dtl.CSVtoRow'>
    <property path='..Source' value='request.Source'/>
    <property path='..CurrentRecord' value='request.RecordNumber'/>
  </transform>

  <call name='InsertMySQL' target='DEMO.bo.MySQLInsert' async='false' request='context.Row'/>
  <return/>
</process>
}
}
