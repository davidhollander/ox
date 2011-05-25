local core=require 'ox.core'
local http=require 'ox.http'
local json=require'json'

http.GET['^/$'] = function(c)
  http.SetHeader(c, 'Content-Type', 'text/html')
  http.RespondFixed(c, 200, [[
    <html>
      <head>
        <title>JSON POST test</title>
        <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.6.1/jquery.min.js"></script>
      </head>
      <body>
        <h1>JSON POST test</h1>
        <div id="message"></div>
        
        <script>
          $(document).ready(function(){
              $.ajax({
                type: 'POST',
                url: '/echo',
                data: {message: 'Hello World'},
                dataType: 'json',
                success: function(data){$('#message').text(data.message)}
              })
          });
        </script>
      </body>
    </html>
  ]])
end

http.POST['^/echo'] = function(c)
  local d=c.req.data
  print(d.message)
  assert(d.message=='Hello World')
  http.Respond(c, 200, json.encode(d))
end

http.Server(8080, http)
print(8080)
core.Loop()
