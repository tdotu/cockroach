cockroach = {}

function cockroach.processRequest(sck,payload)
  local reqType,path,httpver = string.match(payload,"(%u+)%s(%S+)%sHTTP/(%S+)")

  if(reqType == nil or path == nil or httpver == nil) then
    return
  end

  local mime = string.match(payload,"Content%-Type:%s(%S+)")
  if(mime == nil) then
    return
  end

  local data = string.match(payload,".+\r\n\r\n(.+)")
  if(data == nil) then
    return
  end
    for i,v in ipairs(webFiles) do
       if(v.target == path) then
           if(v.file ~= nil) then
                sendFile(sck,v.file,v.mime)
                return
           else
               local mime,str = v.action(mime,data)
               if(mime ~= nil and str ~= nil) then
                 sendSmallString(sck,str,mime)
               end
               return
           end
       end
     end
     cockroach.sendStatusCode(sck,"404 Not Found")
end

function cockroach.start(port)
  srv=net.createServer(net.TCP)
  srv:listen(port,function(conn)
      conn:on("receive",cockroach.processRequest)
  end)
end

function cockroach.loadConfig(table)

end

function cockroach.stop()

end

function cockroach.getFileSize(name)
    local l = file.list();
    local k,v
    for k,v in pairs(l) do
        if k == name then
            return v
        end
    end
    return 0
end

function cockroach.sendFileWorker(c,req)
        if(req.fname == "") then
            return
        end
        if req.fpos >=  req.size then
            c:close()
            req = nil
            collectgarbage()
            return
        end
        file.open(req.fname)
        file.seek("set", req.fpos)
        local str = file.read(500)
        req.fpos = req.fpos + 500
        c:send(str)
        file.close()
end

function cockroach.returnStatusCode(sck,code)
    local error = string.format("<html><head><title>%s</title></head><body><h1>%s</h1></body></html>",code,code)
    sck:send(string.format("HTTP/1.1 %s\nServer: ESP8266\nContent-length: %d\nContent-type: text/html\r\n\r\n%s",code,#error,error))
end

function cockroach.sendFile(sck,fname,mine)
    local req = { fname = fname, fpos = 0, size = cockroach.getFileSize(fname)}
    sck:on("sent", function(c) cockroach.sendFileWorker(c,req) end)
    sck:send(string.format("HTTP/1.1 200 OK\nServer: ESP8266\nContent-length: %d\nContent-type: %s\r\n\r\n",req.size,mine))
end

function cockroach.sendSmallString(sck,str,mime)
    sck:send(string.format("HTTP/1.1 200 OK\nServer: ESP8266\nContent-length: %d\nContent-type: %s\r\n\r\n%s",#str,mime,str))
end
