import db_mysql, jester, asyncdispatch, httpcore, strutils, json

let db = open("localhost", "todo", "todo", "tododb")
db.exec(sql("CREATE TABLE IF NOT EXISTS `todos` (" &
    " `id`         INT(11)       NOT NULL AUTO_INCREMENT PRIMARY KEY, " &
    " `order`      INT(11)       NOT NULL, " &
    " `title`      VARCHAR(255)  NOT NULL, " &
    " `completed`  BOOLEAN       NOT NULL)"))

proc setHeaders(request: Request, headers: StringTableRef) =
  headers["Cache-Control"] = "no-cache"
  if request.headers.hasKey("Origin"):
    headers["Access-Control-Allow-Origin"] = "*"
  if request.headers.hasKey("Access-Control-Request-Method"):
    headers["Access-Control-Allow-Methods"] = "OPTIONS, GET, POST, DELETE, PATCH"
  if request.headers.hasKey("Access-Control-Request-Headers"):
    let values: HttpHeaderValues = request.headers.getOrDefault("Access-Control-Request-Headers")
    headers["Access-Control-Allow-Headers"] = join(seq[string](values), ", ")

proc toJson(row: Row): JsonNode =
  let id = parseInt(row[0])
  result = %* {
      "id":         %* id,
      "order":      %* parseInt(row[1]),
      "title":      %* row[2],
      "completed":  %* (row[3] == "1"),
      "url":        %* ("http://localhost:5000/" & $id)
    }

proc toJson(rows: seq[Row]): JsonNode =
  result = newJArray()
  for row in rows:
    result.add(toJson(row))

routes:
  options "/@id?":
    setHeaders(request, headers)
    resp ""

  get "/@id":
    setHeaders(request, headers)
    let todo = db.getRow(sql("SELECT * FROM todos WHERE id=?"), @"id")
    if todo[0] == "":
      halt Http404
    resp $toJson(todo), "application/json"
    
  get "/":
    setHeaders(request, headers)
    let todos = db.getAllRows(sql("SELECT * FROM todos"))
    resp $toJson(todos), "application/json"
    
  post "/":
    setHeaders(request, headers)
    let input = parseJson(request.body)
    db.exec(sql("INSERT INTO `todos` (`order`, `title`) VALUES (?, ?)"),
        getNum(input.getOrDefault("order")),
        getStr(input.getOrDefault("title")))
    let todo = db.getRow(sql("SELECT * FROM todos WHERE id=LAST_INSERT_ID()"))
    resp $toJson(todo), "application/json"

  delete "/@id":
    setHeaders(request, headers)
    db.exec(sql("DELETE FROM todos WHERE id=?"), @"id")
    resp ""

  delete "/":
    setHeaders(request, headers)
    db.exec(sql("DELETE FROM todos"))
    resp ""

  patch "/@id":
    setHeaders(request, headers)
    let updates = parseJson(request.body)
    if updates.contains("title"):
      db.exec(sql("UPDATE `todos` SET `title`=? WHERE id=?"), getStr(updates["title"]), @"id")
    if updates.contains("order"):
      db.exec(sql("UPDATE `todos` SET `order`=? WHERE id=?"), getNum(updates["order"]), @"id")
    if updates.contains("completed") and getBVal(updates["completed"]):
      db.exec(sql("UPDATE `todos` SET `completed`=1 WHERE id=?"), @"id")
    let todo = db.getRow(sql("SELECT * FROM todos WHERE id=?"), @"id")
    if todo[0] == "":
      halt Http404
    resp $toJson(todo), "application/json"

runForever()

