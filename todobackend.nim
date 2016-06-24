import jester, asyncdispatch, httpcore, strutils, json

let todos = newJArray()

proc getById(id: string): JsonNode =
  for e in todos.elems:
    if e["id"].str == id:
      return e
  return nil

proc deleteById(id: string) =
  for i, e in todos.elems:
    if e["id"].str == id:
      todos.elems.delete(i)

proc setHeaders(request: Request, headers: StringTableRef) =
  headers["Cache-Control"] = "no-cache"
  if request.headers.hasKey("Origin"):
    headers["Access-Control-Allow-Origin"] = "*"
  if request.headers.hasKey("Access-Control-Request-Method"):
    headers["Access-Control-Allow-Methods"] = "OPTIONS, GET, POST, DELETE, PATCH"
  if request.headers.hasKey("Access-Control-Request-Headers"):
    let values: HttpHeaderValues = request.headers.getOrDefault("Access-Control-Request-Headers")
    headers["Access-Control-Allow-Headers"] = join(seq[string](values), ", ")

routes:
  options "/@id?":
    setHeaders(request, headers)
    resp ""

  get "/@id":
    setHeaders(request, headers)
    let todo = getById(@"id")
    if todo == nil:
      halt Http404
    resp $todo, "application/json"
    
  get "/":
    setHeaders(request, headers)
    resp $todos, "application/json"
    
  post "/":
    setHeaders(request, headers)
    let todo = parseJson(request.body)
    let id: string = $(len(todos) + 1)
    todo.add("id", %* id)
    todo.add("completed", %* false)
    todo.add("url", %* ("http://localhost:5000/" & id))
    todos.add(todo)
    resp $todo, "application/json"

  delete "/@id":
    setHeaders(request, headers)
    deleteById(@"id")
    resp ""

  delete "/":
    setHeaders(request, headers)
    todos.elems.setLen(0)
    resp ""

  patch "/@id":
    setHeaders(request, headers)
    let existing = getById(@"id")
    if existing == nil:
      halt Http404
    let updates = parseJson(request.body)
    let keys = @["title", "completed", "order"]
    for key in keys:
      if updates.contains(key):
        existing.add(key, updates[key])
    resp $existing, "application/json"

runForever()
