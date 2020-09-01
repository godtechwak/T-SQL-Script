CREATE Proc SPFinder             
    @pName varchar(30)            
AS             
            
    SELECT DISTINCT a.name             
      FROM sysobjects a             
           JOIN syscomments b on a.id = b.id 
     WHERE b.ctext like '%'+Rtrim(@pName) + '%'            
     ORDER BY a.name           
return
