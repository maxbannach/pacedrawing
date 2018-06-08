---
-- pacedrawing.lua
------------------
-- The Lua backend for pacedrawing.sty
-- This class essently provides methods to parse graphs and
-- tree decompositions stored in .gr or .td fileformat; and then
-- to write them into tikz code.
--
-- Author:  Max Bannach
--
local pacedrawing = {}

---
-- Internal graph representation of the currently parsed graph.
--
-- graph.V[i] = {} if, and only if, i is a vertex in V
-- The content of V[i] may contain two tables: options and label.
--
-- graph.E[i][j] = {} if, and only if, {i,j} is a edge in E
-- The content of E[i][j] are the options applied to this edge.
--
--
-- graph.options is a table containing the options applied to the whole
-- graph.
--
pacedrawing.graph = { options = {}, V = {}, E = {} }

---
-- This is the main function called from the TeX level.
-- It gets a filename and tries to guess the used file format.
-- Once this is done, the following operations will be performed in order:
--   1. parse the given file and build up the corresponding graph
--   2. call @see willGenerateString
--   3. compute a TikZ String with @see generateSring and pipe it to TeX
--   4. call @see didGenerateString
--   5. clear the graph data structure for another run
--
function pacedrawing.pace(filename)  
   local format = pacedrawing.guessFileFormat(filename)
   assert(format ~= "unknown", "I was unable to detect the file format.")

   -- compute the graph
   if format == "dimacs" then
      pacedrawing.parseDimacsGraph(filename)
   elseif format == "td" then
      pacedrawing.parseTreeDecomposition(filename)
   elseif format == "stp" then
      pacedrawing.parseSTPGraph(filename)
   elseif format == "edgelist" then
      pacedrawing.parseEdgelistGraph(filename)
   end

   -- call the anchor function before the string generation
   pacedrawing.willGenerateString(pacedrawing.graph, tikz)
   
   -- pipe the graph to TikZ
   local tikz = pacedrawing.generateString(pacedrawing.graph, tikz)
   tex.sprint(table.concat(tikz, ""));

   -- call the anchor function after the string generation
   pacedrawing.didGenerateString(pacedrawing.graph, tikz)

   -- clear the graph for the next run
   pacedrawing.clearGraph()
end

---
-- Clear the graph, i.e., remove all styles (globally, and for edges and vertices).
--
function pacedrawing.clearGraph()
   pacedrawing.graph.options = {}
   pacedrawing.graph.V = {}
   pacedrawing.graph.E = {}  
   collectgarbage()
end

---
-- Get the fileextention of a filename, i.e., return "gr"
-- if the input is "example.gr"
--
-- This function will return the last extention of the file, i.e.,
-- for input "example2.gr.td" the return is "td".
--
function pacedrawing.getExtention(filename)
   local t = pacedrawing.split(filename, ".")
   assert(#t >= 2)
   return t[#t]
end

---
-- Given the path to a file, this function tries to guess the file format.
-- This often can be done by just checking the file extention. However,
-- sometimes this function will also check the content of the file.
--
-- Possible file formats are:
--   - dimacs
--   - stp
--   - td
--   - edgelist
--
-- If the file format could not be detacted, "unknown" is returned.
--
function pacedrawing.guessFileFormat(filename)

   local ext = pacedrawing.getExtention(filename)
   if ext == "gr" then -- different formats possible

      local pace2018 = false
      local file = io.open(filename)
      for line in file:lines() do
	 if line:find("SECTION") then pace2018 = true end
	 break
      end
      file:close()
      if pace2018 then return "stp" end
      
      return "dimacs"
   elseif ext == "td" then
      return "td"
   elseif ext == "dgf" then
      return "dimacs"
   elseif ext == "stp" then
      return "stp"
   elseif ext == "graph" then
      return "edgelist"
   end

   return "unknown"
end

---
-- Ensures that the given vertex v is present in the graph, i.e.,
-- if it is not part of the graph it will be added.
--
function pacedrawing.ensureVertex(v)
   pacedrawing.graph.V[v] = pacedrawing.graph.V[v] or { options = {} }
end

---
-- Ensures that the given edge {u,v} is in the graph, i.e.,
-- it will be added if it is not present (and multi-edges will never be created).
--
-- This will also ensure that u and v are part of the graph.
--
function pacedrawing.ensureEdge(u, v)
   pacedrawing.ensureVertex(u)
   pacedrawing.ensureVertex(v)
   local g = pacedrawing.graph
   g.E[u] = g.E[u] or {}
   g.E[u][v] = g.E[u][v] or {}
end

---
-- This function is called by the @see pace function before the TikZ string is generated.
-- It gets the current graph g (which was just generated by the pace function) as argument.
--
-- By default, this function does nothing, but it may be override to perform some
-- addional operations on the graph.
--
function pacedrawing.willGenerateString(g)   
end

---
-- Given a internal graph representation, this function will generate a string
-- that can be piped to TiKZ.
--
-- This function returns a string builder table that still needs to be concatenated.
--
function pacedrawing.generateString(g)
   local sb = {}
   sb[#sb+1] = "\\graph["..table.concat(g.options, ", ").."]{"
   
   -- print vertices lexicographically sorted
   for v,t in pacedrawing.spairs(g.V,
				 function(t,a,b)
				    if a:len() < b:len() then return true end
				    if a:len() == b:len() and a < b then return true end
				 end
   ) do
      if t.label then
	 sb[#sb+1] = string.format("  %s / %s;", v, t.label)
      else
	 sb[#sb+1] = string.format("  %s[%s];", v, table.concat(t.options, ", "))
      end
   end

   for u,N in pacedrawing.spairs(g.E) do
      for v,opt in pacedrawing.spairs(N) do
	 sb[#sb+1] = string.format("  %s --[%s] %s;", u, table.concat(opt, ", "), v)
      end
   end
   
   sb[#sb+1] = "};"
   return sb
end

---
-- This function is called whenever the @see pace function is completed.
-- It gets the current graph g (which was just generated by the pace function) as
-- well as a corresponding TikZ string representation of it as argument (as string builder table).
--
-- By default this function does nothing, but it may be override to perform some
-- addional operations on the graph.
--
-- Note that, after that function was called, the internal data structures get cleared, i.e.,
-- the graph is then not present anymore.
--
function pacedrawing.didGenerateString(g, tikz)
end

---
-- Parse a graph stored in dimacs format (or the simpler PACE format).
-- This function will modify the internal representation of the graph.
--
function pacedrawing.parseDimacsGraph(filename)
   table.insert(pacedrawing.graph.options, "pace/dimacs")
   local file = io.open(filename, "r")
   for line in file:lines() do
      local t = pacedrawing.split(line, " ")
      if t[1] == "p" then -- handle problem definition line
	 local n = t[3]
	 for i = 1,n do
	    pacedrawing.ensureVertex(tostring(i))
	 end
      elseif (t[1] == "c" or
		 t[1] == "n" or
		 t[1] == "d" or
		 t[1] == "v" or
		 t[1] == "x" or
		 t[1] == "b" or
		 t[1] == "l") then
	 -- skip commit line and .dgf information
      elseif t[1] == "e" then -- handle diamcs edge
	 pacedrawing.ensureEdge(t[2], t[3])
      else -- handle .gr edge
	 pacedrawing.ensureEdge(t[1], t[2])
      end
   end
   file:close()
end

---
-- Read a .td file storing a tree decomposition.
-- This function will modify the internal representation of the graph.
--
function pacedrawing.parseTreeDecomposition(filename)
   table.insert(pacedrawing.graph.options, "pace/treedecomposition")
   local file = io.open(filename, "r")
   for line in file:lines() do
      local t = pacedrawing.split(line, " ")
      if t[1] ~= "c" and t[1] ~= "s" then
	 if t[1] == "b" then
	    local v = t[2]
	    local text = ""
	    if #t > 2 then
	       text = "\\{"..t[3]
	       for i = 4,#t do text = text.."{,}"..t[i] end
	       text = text.."\\}"
	    else
	       text = "\\{\\}"
	    end
	    pacedrawing.ensureVertex(t[2])
	    pacedrawing.graph.V[t[2]].label = text
	 else
	    pacedrawing.ensureEdge(t[1], t[2])
	 end
      end
   end
   file:close()
end

---
-- Read a .gr file that encodes a STP / PACE 2018 steiner tree instance.
-- This function will modify the internal representation of the graph.
--
function pacedrawing.parseSTPGraph(filename)
   table.insert(pacedrawing.graph.options, "pace/stp")
   local file = io.open(filename, "r")
   for line in file:lines() do
      local t = pacedrawing.split(line, " ")
      if t[1] == "Nodes" then
   	 local n = t[2]
   	 for i = 1,n do
   	    pacedrawing.ensureVertex(tostring(i))
   	 end
      elseif t[1] == "E" then
   	 pacedrawing.ensureEdge(t[2], t[3])
   	 if pacedrawing.showEdgeWeights then
   	    table.insert(pacedrawing.graph.E[t[2]][t[3]], "\""..t[4].."\"")
   	 end
      elseif t[1] == "T" then
   	 table.insert(pacedrawing.graph.V[t[2]].options, "terminal")
      end
   end   
   file:close()
end

---
-- Read a .graph file that encodes a graph as simple edge list (PCACE 16/17 Track B).
-- This function will modify the internal representation of the graph.
--
function pacedrawing.parseEdgelistGraph(filename)
   table.insert(pacedrawing.graph.options, "pace/edgelist")
   local file = io.open(filename, "r")
   for line in file:lines() do
      local t = pacedrawing.split(line, " ")
      if t[1] ~= "#" then
	 pacedrawing.ensureEdge(t[1], t[2])
      end      
   end
   file:close()
end

---
-- Get an option / style as argument and apply it to the current graph.
--
function pacedrawing.addOptionToGraph(opt)
   table.insert(pacedrawing.graph.options, opt)
end

---
-- Get an array of vertices and adds the given option (which should be a string) to
-- these vertices.
--
function pacedrawing.addOptionToVertices(S, opt)
   for _,v in ipairs(S) do
      pacedrawing.ensureVertex(tostring(v))
      table.insert(pacedrawing.graph.V[tostring(v)].options, opt)
   end
end

---
-- Get an array of edges and adds the given option (which should be a string) to
-- these eges.
--
function pacedrawing.addOptionToEdges(S, opt)
   for _,e in ipairs(S) do
      local u = tostring(e[1])
      local v = tostring(e[2])
      pacedrawing.ensureEdge(u, v)
      table.insert(pacedrawing.graph.E[u][v], opt)
   end
end

---
-- Helper function to split the given string s at tokens p.
--
function pacedrawing.split(s, p)
   local seperator = p or "%s"
   local t = {}
   for component in s:gmatch("([^"..seperator.."]+)") do
      t[#t+1] = component
   end
   return t
end

---
-- Iterate over the table (as pairs) in sorted order.
-- If no iterator is given, this will be done by sorting the keys lexicographically,
-- other wise the comparator is used.
-- The comparator should be a function that gets three arguments, the table and two keys,
-- and should return true if the first key should be ordered smaller.
--
function pacedrawing.spairs(t, comparator)
   -- get the keys used in table t
   local keys = {}
   for k in pairs(t) do keys[#keys+1] = k end

   -- either lex-sort by the keys, or with the given comparator
   if comparator then
      table.sort(keys, function(a,b) return comparator(t, a, b) end)
   else
      table.sort(keys)
   end

   -- return sorted iterator
   local i = 0
   return function()
      i = i + 1
      if keys[i] then
	 return keys[i], t[keys[i]]
      end
   end
end

-- done
return pacedrawing
