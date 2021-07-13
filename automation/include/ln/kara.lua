local util = require 'aegisub.util'
local unicode = require 'unicode'

local matchfloat = "%-?%f[%.%d]%d*%.?%d*%f[^%.%d%]]"

local function booltost(bool)
  if bool == nil then
    return "nil";
  end
  if bool then
    return "true";
  else
    return "false";
  end
end

local function tabletost(t, depth)
  local tabst = ""
  depth = depth or 0
  for key, val in pairs(t) do
      for i=1,depth do
          tabst = tabst .. "  "
      end
      tabst = tabst .. (key .. ": " .. tostring(val) .. "\n")
      if type(val) == "table" then
          tabst = tabst .. tabletost(val, depth + 1)
      end
  end
  return tabst;
end

local function makestring(variable)
  if variable == nil then
    return "nil"
  elseif type(variable) == "number" or type(variable) == "string" then
    return tostring(variable)
  elseif type(variable) == "boolean" then
    return booltost(variable)
  elseif type(variable) == "table" then
    return tabletost(variable)
  else
    aegisub.debug.out("unknown")
    return type(variable)
  end
end

local function findtag(text, tagtype, startindex, endindex)
  local valuestarts = "[0123456789%&%-%(]"
  if tagtype == nil then tagtype = "[^\\%}]"; valuestarts = "[^\\%}]" end
  if tagtype == "fn" then valuestarts = "[^\\%}]" end
  if tagtype == "t" then valuestarts = "[(]" end
  if tagtype == "inline_fx" then tagtype = "%-"; valuestarts = "[^\\%}]"; end
  if tagtype == "c" or tagtype == "1c" then tagtype = "1?c" end
  if startindex == nil then startindex = 1 end
  if endindex == nil then endindex = -1 end
  if text == nil then return 0,0 end
  local tagstart = text:find(("\\%s%s"):format(tagtype,valuestarts), startindex)
  if tagstart == nil then return 0,0 end
  local depth = 0
  for i=startindex,tagstart do
    local c = text:sub(i,i)
    if c == "(" then depth = depth + 1 end
    if c == ")" then depth = depth - 1 end
  end
  if depth ~= 0 then
    return 0,0
  end
  depth = 0
  local max_i = endindex
  if max_i < 0 then max_i = text:len() + 1 + max_i end
  for i = tagstart + 1, math.min(text:len(), max_i) do
    local c = text:sub(i, i)
    if c == "(" then depth = depth + 1 end
    if c == ")" then depth = depth - 1 end
    --if tagtype == "t" then aegisub.debug.out("i=".. i ..", c=".. c ..", depth=".. depth .."\n") end;
    if c == "}" or (c == "\\" and depth == 0) then
      return tagstart, i - 1
    end
  end
  return 0,0
end

local tenv

local function an2point(alignment)
  local x = 1 + ((alignment - 1) % 3);
  local y = 1 + (alignment - x) / 3;
  local yval = tenv.line.bottom;
  local xval
  if y == 2 then
    yval = tenv.line.middle;
  elseif y > 2 then
    yval = tenv.line.top;
  end
  if tenv.syl ~= nil then
    xval = tenv.line.left + tenv.syl.left;
    if x == 2 then
      xval = tenv.line.left + tenv.syl.center;
    elseif x > 2 then
      xval = tenv.line.left + tenv.syl.right;
    end
  else
    xval = tenv.line.left;
    if x == 2 then
      xval = tenv.line.center;
    elseif x > 2 then
      xval = tenv.line.right;
    end
  end
  return xval, yval;
end

local lnlib

local function startbuffertime(k_min, fad_min)
  if lnlib.line.tag("fad") ~= "" then
    return math.max(fad_min, tonumber(string.match(lnlib.line.tag("fad"), "(%d+),%s*%d+"))), true
  else
    if #(tenv.line.kara or {}) == 0 then
      return k_min, false
    end
    if tenv.line.kara[1].text == "" or tenv.line.kara[1].text == " " then
      return math.max(k_min, tenv.line.kara[1].duration), false
    end
  end
  return k_min, false;
end

local function endbuffertime(k_min, fad_min)
  if lnlib.line.tag("fad") ~= "" then
    return math.max(fad_min, tonumber(string.match(lnlib.line.tag("fad"), "%d+,%s*(%d+)"))), true
  else
    if #(tenv.line.kara or {}) == 0 then
      return k_min, false
    end
    if tenv.line.kara[#(tenv.line.kara)].text == "" or tenv.line.kara[#(tenv.line.kara)].text == " " then
      return math.max(k_min, tenv.line.kara[#(tenv.line.kara)].duration), false
    end
  end
  return k_min, false
end

local RGB2HSL = function(r,g,b)
  r = r / 255
  g = g / 255
  b = b / 255
  local ma = math.max(r, g, b);
  local mi = math.min(r, g, b);
  local c = ma - mi;

  --calculate hue
  local h = nil;
  if c ~= 0 then
    if ma == r then
      h = (((g - b) / c) % 6) / 6;
    elseif ma == g then
      h = ((b - r) / c + 2) / 6;
    else
      h = ((r - g) / c + 4) / 6;
    end
  end

  --calculate lightness
  local l = (ma + mi) / 2;

  local s
  --calculate saturation
  if l == 0 or l == 1 then
    s = 0;
  else
    s = c / (1 - math.abs(2 * l - 1));
  end
  return (h or 0)*255, s*255, l*255
end

local HSL2RGB = function(h, s, l)
  h = h / 255
  s = s / 255
  l = l / 255
  local r = 0;
  local g = 0;
  local b = 0;
  --chroma
  local c = (1 - math.abs(2 * l - 1)) * s;
  local m = l - c / 2;

  --- if not grayscale, calculate RGB
  if h ~= nil then
    local hu = (h%1) * 6;
    local x = c * (1 - math.abs(hu % 2 - 1));
    if hu < 1 then
      r = c;
      g = x;
    elseif hu < 2 then
      r = x;
      g = c;
    elseif hu < 3 then
      g = c;
      b = x;
    elseif hu < 4 then
      g = x;
      b = c;
    elseif hu < 5 then
      r = x;
      b = c;
    else
      r = c;
      b = x;
    end
  end

  return 255*(r+m),255*(g+m),255*(b+m)
end

local function formtag(tag, argumentlist)
  if type(argumentlist) ~= "table" then argumentlist = { argumentlist } end;
  local value = argumentlist[1];
  
  if #argumentlist == 1 then
    if type(value) == "number" then
      if tag == "alpha" or tag == "1a" or tag == "2a" or tag == "3a" or tag == "4a" then
        value = lnlib.math.clamp(value, 0, 255)
        return ("\\%s&H%02X&"):format(tag, value);
      else
        return ("\\%s%.2f"):format(tag,value);
      end
    else
      return ("\\%s%s"):format(tag,value);
    end
  end

  for i = 2, #argumentlist do
    if type(argumentlist[i]) == "number" then
      argumentlist[i] = ("%.2f"):format(argumentlist[i])
    end
  end
  return ("\\%s(%s)"):format(tag,table.concat(argumentlist, ", "));
end

local function formtags(taglist, argumentlist)
  if type(taglist) ~= "table" then taglist = { taglist } end
  if type(argumentlist) ~= "table" then argumentlist = { argumentlist } end
  local tagstrings = {}
  for i = 1, #taglist do
    table.insert(tagstrings, formtag(taglist[i], argumentlist[((i-1) % #(argumentlist))+1]))
  end
  return table.concat(tagstrings)
end

local function calcTable(functions, value)
  local outt = {}
  if type(functions) ~= "table" then functions = {functions} end
  for i = 1, #functions do
    outt[i] = functions[i](value)
  end
  return outt
end

local function formtagsv2(tags_with_funcs, value)
  local tagstrings = {}
  for i = 1, #tags_with_funcs do
    table.insert(tagstrings, formtag(tags_with_funcs[i][1], tags_with_funcs[i][2](value)))
  end
  return table.concat(tagstrings)
end

local function shiftDrawing(str, x, y)
  local txt = str
  local i = 1
  while true do
    local pair = txt:match("%-?%d+ %-?%d+", i)
    if not pair then break end
    local starti = txt:find("%-?%d+ %-?%d+", i)
    local origlen = #pair
    local pairx = pair:match("%-?%d+")
    local pairy = pair:match("%-?%d+", pair:find(pairx)+#pairx)
    pair = string.format("%d %d",tonumber(pairx) + x, tonumber(pairy) + y)
    txt = txt:sub(1,starti-1) .. pair .. txt:sub(starti + origlen)
    i = starti + #pair
  end
  --aegisub.debug.out("shifted ".. str .." by ".. x ..",".. y .." -> ".. txt .."\n")
  return txt
end

local function cleartable(table)
  for i in pairs(table) do
    table[i] = nil
  end
end

local function paircount(table)
  local count = 0
  for k,v in pairs(table) do
    count = count + 1
  end
  return count
end

local randomizer_table = {}
local buffers = {}

lnlib = {
  init = function(tv)
    tenv = tv
    --tv.ci = lnlib.chari not relevant and also broken with kara templater mod, use syl.ci for all your needs
    tv.st = lnlib.syltime
    tv.sd = lnlib.syldur
    tv.gc = lnlib.line.c
    tv.ga = lnlib.line.a
    tv.rgb = lnlib.color.byRGB
    tv.hsl = lnlib.color.byHSL
    tv.hsy = lnlib.color.lumaHSL
    tv.rnd = lnlib.math.random
    tv.set = function(var, val) tenv[var] = val return "" end
    tv.rset = lnlib.randomize
    tv.clamp = lnlib.math.clamp
    tv.fl = math.floor
    cleartable(randomizer_table)
    cleartable(buffers)
  end,
  --[[ chari = function() -- not relevant and also broken with kara templater mod, use syl.ci for all your needs
    local out = 0
    for i=1,tenv.syl.i-1 do
      out = out + unicode.len(tenv.line.kara[i].text_stripped)
    end
    return (tenv.syl.ci or 1) + out
  end, ]]--
  syltime = function(p)
    return tenv.syl.start_time+tenv.syl.duration*(p or 0)
  end,
  syldur = function(p)
    return tenv.syl.duration*(p or 0)
  end,
  randomize = function(variable_name, min, max, override)
    if not override and randomizer_table[variable_name] == nil and tenv[variable_name] ~= nil then
      aegisub.log("Variable '".. variable_name .."' not randomized; already set & override not enabled.\n")
    else
      local new_var = math.random(min, max)
      randomizer_table[variable_name] = new_var
      tenv[variable_name] = new_var
    end
    return ""
  end,
  line = {
    tag = function (tags)
      local ret = {}
      if type(tags) == "string" then tags = {tags} end
      for key,val in pairs(tags) do
        table.insert(ret,tenv.line.raw:sub(findtag(tenv.line.raw, val)))
      end
      return table.concat(ret)
    end,
    tags = function (tags, as_list)
      local ret = {}
      if type(tags) == "string" then tags = {tags} end
      for i=1,#tags do
        local ci = 1
        while ci < #tenv.line.raw and ci > 0 do
          local si, ei = findtag(tenv.line.raw, tags[i], ci)
          if ei and ei ~= 0 then
            ci = ei+1
            table.insert(ret, tenv.line.raw:sub(si, ei))
          else ci = -1 end
        end
      end
      return as_list and ret or table.concat(ret)
    end,
    style_c = function(n)
      n = n or 1
      return color_from_style(tenv.line.styleref["color" .. n])
    end,
    style_a = function(n)
      n = n or 1
      return alpha_from_style(tenv.line.styleref["color" .. n])
    end,
    c = function(n)
      n = n or 1
      local tag = lnlib.line.tags(n .. "c")
      if tag ~= "" then
        return tag:match("&H%x%x%x%x%x%x&")
      else
        return color_from_style(tenv.line.styleref["color" .. n]);
      end
    end,
    a = function(n)
      n = n or 1
      local tag = lnlib.line.tags(n .. "a")
      if tag ~= "" then
        return tag:match("&H%x%x&")
      else
        return alpha_from_style(tenv.line.styleref["color" .. n]);
      end
    end,
    buffers = function(startmin_k, endmin_k, startmin_fad, endmin_fad)
      local buf = buffers[tenv.line.start_time .."-".. tenv.line.end_time]
      if buf == nil then
        startmin_fad = startmin_fad or startmin_k
        endmin_fad = endmin_fad or endmin_k
        local fromtag = false
        buf = {}
        buf.sb, fromtag = startbuffertime(0, 0)
        buf.sb = math.max(buf.sb, fromtag and startmin_fad or startmin_k)
        buf.eb, fromtag = endbuffertime(0, 0)
        buf.eb = math.max(buf.eb, fromtag and endmin_fad or endmin_k)
        buffers[tenv.line.start_time .."-".. tenv.line.end_time] = buf
      end
      return buf.sb,buf.eb
    end,
    len_stripped = function()
      return unicode.len(tenv.line.text_stripped)
    end,
    len = function()
      return unicode.len(tenv.line.text)
    end,
    len_raw = function()
      return unicode.len(tenv.line.raw)
    end
  },
  
  syl = {
    tag = function (tags) -- kara tags are lost forever on the syl level due to karaskel, but the rest can still be found
      local ret = {}
      if type(tags) == "string" then tags = {tags} end
      for i=1,#tags do
        table.insert(ret,tenv.syl.text:sub(findtag(tenv.syl.text, tags[i])))
      end
      return table.concat(ret)
    end,
    tags = function (tags, as_list)
      local ret = {}
      if type(tags) == "string" then tags = {tags} end
      for i=1,#tags do
        local ci = 1
        while ci < #tenv.syl.text and ci > 0 do
          local si, ei = findtag(tenv.syl.text, tags[i], ci)
          if ei and ei ~= 0 then
            ci = ei+1
            table.insert(ret, tenv.syl.text:sub(si, ei))
          else ci = -1 end
        end
      end
      return as_list and ret or table.concat(ret)
    end,
    c = function(n)
      n = n or 1
      local tag = lnlib.syl.tags(n .. "c")
      if tag ~= "" then
        return tag:match("&H%x%x%x%x%x%x&")
      else
        return color_from_style(tenv.line.styleref["color" .. n]);
      end
    end,
    a = function(n)
      n = n or 1
      local tag = lnlib.syl.tags(n .. "a")
      if tag ~= "" then
        return tag:match("&H%x%x&")
      else
        return alpha_from_style(tenv.line.styleref["color" .. n]);
      end
    end,
    len_stripped = function()
      return unicode.len(tenv.syl.text_stripped)
    end,
    len = function()
      return unicode.len(tenv.syl.text)
    end
  },

  tag = {
    pos = function(alignment, anchorpoint, xoffset, yoffset, line_kara_mode)
      if type(alignment) == "table" then
        alignment = alignment.alignment or tenv.line.styleref.align or 5
        anchorpoint = alignment.anchorpoint or alignment or tenv.line.styleref.align or 5
        xoffset = alignment.offset_x or 0
        yoffset = alignment.offset_y or 0
        line_kara_mode = alignment.line_kara_mode
      else
        alignment = alignment or tenv.line.styleref.align or 5
        anchorpoint = anchorpoint or alignment or tenv.line.styleref.align or 5
        xoffset = xoffset or 0
        yoffset = yoffset or 0
      end
      local x,y
      if line_kara_mode then
        if not tenv.line.smart_pos_flag then
          x,y = an2point(anchorpoint)
          tenv.line.smart_pos_flag = true
        end
      elseif tenv.syl == nil then
        x,y = an2point(anchorpoint)
      else
        x,y = an2point(anchorpoint)
      end
      if x ~= nil and y~= nil then
        return ("\\an%d\\pos(%.2f,%.2f)"):format(alignment,x + xoffset,y + yoffset);
      else
        return "";
      end
    end,
    kanjipos = function(xoffset, yoffset, line_kara_mode) -- fuck it, using fixed an5 | also this breaks if rotation is used for anything else
      local alignment
      local anchorpoint
      if type(xoffset) == "table" then
        alignment = 5
        anchorpoint = 5
        xoffset = (xoffset.offset_x or 0)
        yoffset = (xoffset.offset_y or 0)
        line_kara_mode = xoffset.line_kara_mode
      else
        alignment = 5
        anchorpoint = 5
        xoffset = (xoffset or 0)
        yoffset = (yoffset or 0)
      end
      local w = tenv.line.height
      local h = tenv.line.chars[1].width -- breaks if line starts with non-fullwidth char lol
      local x,y
      
      local lineal = tenv.line.styleref.align
      if line_kara_mode and tenv.line.smart_pos_flag then
        return ""
      else
        if lineal % 3 == 1 then
          x = tenv.line.left + h/2
        elseif lineal % 3 == 0 then
          x = tenv.line.right - h/2
        else
          x = tenv.line.center
        end
        if line_kara_mode then
          if lineal < 4 then
            y = tenv.line.bottom - tenv.line.width/2
          elseif lineal > 6 then
            y = tenv.line.top + tenv.line.width/2
          else
            y = tenv.line.middle
          end
        else
          if lineal < 4 then
            y = tenv.line.bottom - (tenv.line.width-tenv.syl.center) - (w-h)/2
          elseif lineal > 6 then
            y = tenv.line.top + tenv.syl.center + (w-h)/2
          else
            y = tenv.line.middle + tenv.syl.center - tenv.line.width/2
          end
        end
        tenv.line.smart_pos_flag = true
      end
      
      if x ~= nil and y~= nil then
        local fontchange = ""
        if tenv.line.styleref.fontname:sub(1,1) ~= "@" then
          fontchange = "\\fn@" .. tenv.line.styleref.fontname
        end
        return ("%s\\frz-90\\an%d\\pos(%.2f,%.2f)"):format(fontchange, alignment,x + xoffset,y + yoffset);
      else
        return "";
      end
    end,
    move = function(xoff0, yoff0, xoff1, yoff1, time0, time1, alignment, anchorpoint, line_kara_mode)
      if type(xoff0) == "table" then
        local tab = xoff0
        alignment = tab.alignment or tenv.line.styleref.align or 5
        anchorpoint = tab.anchorpoint or alignment or tenv.line.styleref.align or 5
        xoff0 = tab.offset_x_start or tab.x0 or 0
        yoff0 = tab.offset_x_start or tab.y0 or 0
        xoff1 = tab.offset_x_end or tab.x1 or 0
        yoff1 = tab.offset_x_end or tab.y1 or 0
        time0 = tab.time_start or tab.t0 or nil
        time1 = tab.time_end or tab.t1 or nil
        line_kara_mode = tab.line_kara_mode
      else
        alignment = alignment or tenv.line.styleref.align or 5
        anchorpoint = anchorpoint or tenv.line.styleref.align or 5
        xoff1 = xoff1 or 0
        yoff1 = yoff1 or 0
      end
      local x,y
      if line_kara_mode then
        if not tenv.line.smart_pos_flag then
          x,y = an2point(anchorpoint)
          tenv.line.smart_pos_flag = true
        end
      elseif tenv.syl == nil then
        x,y = an2point(anchorpoint)
      else
        x,y = an2point(anchorpoint)
      end
      local timest;
      if time0 == nil or time1 == nil then
        timest = ""
      else
        timest = (",%d,%d"):format(time0,time1)
      end
      if x ~= nil and y~= nil then
        return ("\\an%d\\move(%.2f,%.2f,%.2f,%.2f%s)"):format(alignment,x + xoff0,y + yoff0,x + xoff1,y + yoff1,timest);
      else
        return "";
      end
    end,
    t = function(a0, a1, a2, a3)
      if a1 == nil and a2 == nil and a3 == nil then
        a3 = a0; a0 = nil
      elseif a2 == nil and a3 == nil then
        a2 = a0; a3 = a1; a0 = nil; a1 = nil
      elseif a3 == nil then
        a3 = a2; a2 = nil
      end
      local st = {}
      if a0 then table.insert(st, string.format("%d",a0)) end
      if a1 then table.insert(st, string.format("%d",a1)) end
      if a2 then table.insert(st, string.format("%.2f",a2)) end
      table.insert(st, a3)
      return ("\\t(%s)"):format(table.concat(st,","))
    end,
    parse_transform = function(tag)
      if not tag:match("\\t%(") then return nil end
      local f = matchfloat
      local t0, t1, a, tags
      t0, t1, a, tags = tag:match(("\\t%%((%s),(%s),(%s),(.*)%%)"):format(f,f,f))
      if tags == nil then
        t0, t1, tags = tag:match(("\\t%%((%s),(%s),(.*)%%)"):format(f,f))
      end
      if tags == nil then
        a, tags = tag:match(("\\t%%((%s),(.*)%%)"):format(f))
      end
      if tags == nil then
        tags = tag:match("\\t%((.*)%)")
      end
      return {t0 = tonumber(t0), t1 = tonumber(t1), a = tonumber(a or 1), tags = tags}
    end,
    mod_transform = function(tag, t0mod, t1mod, amod, tagsmod)
      if not tag or tag == "" then return "" end
      if type(tag) == "string" then tag = {tag} end
      local ret = {}
      for i=1,#tag do
        local parsed = lnlib.tag.parse_transform(tag[i])
        local newt0, newt1, newa, newtags

        if t0mod == nil or t0mod == "" or t0mod == 0 or parsed.t0 == nil then
          newt0 = parsed.t0
        elseif t0mod:sub(1,1) == "-" then
          newt0 = parsed.t0 - tonumber(t0mod:sub(2))
        elseif t0mod:sub(1,1) == "+" then
          newt0 = parsed.t0 + tonumber(t0mod:sub(2))
        elseif t0mod:sub(1,1) == "=" then
          newt0 = tonumber(t0mod:sub(2))
        else
          newt0 = tonumber(t0mod)
        end

        if t1mod == nil or t1mod == "" or t1mod == 0 or parsed.t1 == nil then
          newt1 = parsed.t1
        elseif t1mod:sub(1,1) == "-" then
          newt1 = parsed.t1 - tonumber(t1mod:sub(2))
        elseif t1mod:sub(1,1) == "+" then
          newt1 = parsed.t1 + tonumber(t1mod:sub(2))
        elseif t1mod:sub(1,1) == "=" then
          newt1 = tonumber(t1mod:sub(2))
        else
          newt1 = tonumber(t1mod)
        end

        if amod == nil or amod == "" or amod == 0 then
          newa = parsed.a
        elseif amod:sub(1,1) == "-" then
          newa = parsed.a - tonumber(amod:sub(2))
        elseif amod:sub(1,1) == "+" then
          newa = parsed.a + tonumber(amod:sub(2))
        elseif amod:sub(1,1) == "=" then
          newa = tonumber(amod:sub(2))
        else
          newa = tonumber(amod)
        end

        if tagsmod == nil or tagsmod == "" then
          newtags = parsed.tags
        elseif tagsmod:sub(1,1) == "-" then
          newtags = string.gsub(parsed.tags, tagsmod:sub(2),"")
        elseif tagsmod:sub(1,1) == "+" then
          newtags = parsed.tags .. tagsmod:sub(2)
        elseif tagsmod:sub(1,1) == "=" then
          newtags = tagsmod:sub(2)
        else
          newtags = tagsmod
        end

        table.insert(ret,lnlib.tag.t(newt0, newt1, newa, newtags))
      end
      return table.concat(ret)
    end,
    parse_move = function(tag)
      if not tag:match("\\move%(") then return nil end
      local f = matchfloat
      local x0, y0, x1, y1, t0, t1
      x0, y0, x1, y1, t0, t1 = tag:match(("\\move%%((%s),(%s),(%s),(%s),(%s),(%s)%%)"):format(f,f,f,f,f,f))
      if t1 == nil then
        x0, y0, x1, y1 = tag:match(("\\move%%((%s),(%s),(%s),(%s)%%)"):format(f,f,f,f))
      end
      return {x0 = tonumber(x0), y0 = tonumber(y0), x1 = tonumber(x1), y1 = tonumber(y1), t0 = tonumber(t0), t1 = tonumber(t1)}
    end
  },

  wave = {
    new = function()
      local ftable = {}
      return {
        addWave = function(waveform, wavelength, amplitude, phase)
          amplitude = amplitude or 1
          phase = phase or 0
          if waveform == "noise" or waveform == "random" then
            local randomvalues = {}
            math.randomseed(phase)
            for i = 1, wavelength do
              randomvalues[math.floor((i+phase) % wavelength) + 1] = amplitude * (math.random() * 2 - 1)
            end
            table.insert(ftable, {form="noise", w=wavelength,a=amplitude,p=phase, val=randomvalues})
          else
            table.insert(ftable, {form=waveform, w=wavelength,a=amplitude,p=phase})
          end
          return ""
        end,

        addFunction = function(func)
          table.insert(ftable, {form="function", f = func})
          return ""
        end,

        clear = function()
          cleartable(ftable)
        end,

        setWave = function(waveform, wavelength, amplitude, phase)
          cleartable(ftable)
          if waveform == "noise" or waveform == "random" then
            local randomvalues = {}
            math.randomseed(phase)
            for i = 1, wavelength do
              randomvalues[math.floor((i+phase) % wavelength) + 1] = amplitude * (math.random() * 2 - 1)
            end
            table.insert(ftable, {form="noise", w=wavelength,a=amplitude,p=phase, val=randomvalues})
          else
            table.insert(ftable, {form=waveform, w=wavelength,a=amplitude,p=phase})
          end
          return ""
        end,

        setFunction = function(func)
          cleartable(ftable)
          table.insert(ftable, {form="function", f = func})
          return ""
        end,

        getValue = function(time)
          local y = 0
          for key,wave in pairs(ftable) do
            if wave.form == "noise" then
              y = y + wave.val[math.floor((time % wave.w) + 1)];
            elseif wave.form == "square" then
              y = y + wave.a * 2 * (0.5 - math.floor(((time / wave.w + wave.p) * 2 )) % 2)
            elseif wave.form == "triangle" then
              y = y + wave.a * (math.abs(((time / wave.w + wave.p - 0.25) % 1) * 4 - 2) - 1)
            elseif wave.form == "sawtooth" then
              y = y + wave.a * (((time / wave.w + wave.p - 0.5) % 1)*2 - 1)
            elseif wave.form == "function" then
              y = y + wave.f(time)
            else
              y = y + wave.a * math.sin(time*math.pi*2/wave.w + wave.p*math.pi*2)
            end
          end
          return y
        end
      }
    end,

    transform = function(wave, tags, starttime, endtime, delay, framestep, jumpToStartingPosition, argY, argZ)
      framestep = framestep or 2
      starttime = starttime or 0
      endtime = endtime or tenv.line.duration
      delay = delay or 0
      
      local modifierFunctions
      local dutyCycle
      if argY and type(argY) == "number" then
        dutyCycle = argY
      else
        modifierFunctions = argY
        dutyCycle = argZ
      end

      local identity = function(x) return x end

      if type(tags) == "string" then
        tags = {{tags, identity}}
      else
        for i,val in ipairs(tags) do
          if type(val) ~= "table" then
            tags[i] = {val, identity}
          elseif val[2] == nil then
            val[2] = identity
          end
        end
      end
      -- transform old syntax into new syntax
      if modifierFunctions then
        aegisub.log(2, "Warning: this syntax is deprecated. Instead of a separate modifierFunctions table, please bundle the modifier functions with their tags in the tags table. For more information, see the readme.\n")
        for i,val in ipairs(tags) do
          local modfun = modifierFunctions[(i-1) % #modifierFunctions+1]
          if type(modfun) == "function" then
            val[2] = modfun
          elseif modfun ~= nil then
            aegisub.log(2, "Warning: modifierFunctions should be functions. Got %s for tag \\%s\n", type(modfun), val[1])
          end
        end
      end

      dutyCycle = dutyCycle or 1

      if jumpToStartingPosition == nil then jumpToStartingPosition = true end

      local timestep = framestep * 1000 / 23.976
      local tfs = {}
      local prevtags = ""
      if jumpToStartingPosition then
        local firsttags = formtagsv2(tags, wave.getValue(starttime - delay))
        table.insert( tfs, lnlib.tag.t(starttime, starttime + 1, 1, firsttags) )
        prevtags = firsttags
      end
      for i = starttime, endtime - 1, timestep do
        local t0 = i
        if jumpToStartingPosition and i == starttime then
          t0 = i + 1
        end
        local t1 = t0 + timestep * dutyCycle + 1

        local val0    = wave.getValue(i - delay)
        local valHalf = wave.getValue(i + timestep / 2 - delay)
        local val1    = wave.getValue(i + timestep - delay)

        --[[
        -- Assumed ASS accel curve:
        -- ratio = ((t - t0) / (t1 - t0)) ^ accel
        -- value = val0 + (val1 - val0) * ratio
        -- Ratio range is 0-1 so exponent just curves it.
        -- knowns: value = valHalf
        -- ((t - t0) / (t1 - t0)) = 0.5 since we're halfway through the timestep, so:
        --  ratio = 0.5 ^ accel
        -- place the knowns into the latter equation:
        -- valHalf = val0 + (val1 - val0) * 0.5 ^ accel
        -- (valHalf - val0) / (val1 - val0) = 0.5 ^ accel
        -- log_0.5( (valHalf - val0) / (val1 - val0) ) = log_0.5(0.5 ^accel) = accel
        --]]
        local accel_unclamped = lnlib.math.log(0.5, math.abs((valHalf - val0) / (val1 - val0)))
        local accel = lnlib.math.clamp(accel_unclamped, 0.01, 100);
        
        local _tags = formtagsv2(tags, val1)
        if _tags ~= prevtags then
          table.insert( tfs, lnlib.tag.t(t0, t1, accel, _tags) )
          prevtags = _tags
        end
      end
      return table.concat(tfs)
    end
  },

  color = {
    byRGB = function(r,g,b)
      return string.format("&H%02X%02X%02X&",b,g,r)
    end,
    byHSL = function(h, s, l)
      h = h / 255
      s = s / 255
      l = l / 255
      local r = 0;
      local g = 0;
      local b = 0;
      --chroma
      local c = (1 - math.abs(2 * l - 1)) * s;
      local m = l - c / 2;

      --- if not grayscale, calculate RGB
      if h ~= nil then
        local hu = (h%1) * 6;
        local x = c * (1 - math.abs(hu % 2 - 1));
        if hu < 1 then
          r = c;
          g = x;
        elseif hu < 2 then
          r = x;
          g = c;
        elseif hu < 3 then
          g = c;
          b = x;
        elseif hu < 4 then
          g = x;
          b = c;
        elseif hu < 5 then
          r = x;
          b = c;
        else
          r = c;
          b = x;
        end
      end

      return string.format("&H%02X%02X%02X&",255*(b+m),255*(g+m),255*(r+m))
    end,
    lumaHSL = function(h,s,l)
      if h == nil then
        return "&H000000&"
      end
      local y1 = l;
      local r, g, b = HSL2RGB(h, s, l)
      local y2 = r * 0.2126 + g * 0.7152 + b * 0.0722;
      local lumashift = y2 / y1;
      r = math.min(255, r / lumashift);
      g = math.min(255, g / lumashift);
      b = math.min(255, b / lumashift);
      return lnlib.color.byRGB(r,g,b);
    end,
    rgb = {
      get = function(string)
        local r, g, b = extract_color(string)
        return r,g,b
      end,
      add = function(string, dr, dg, db)
        local r, g, b = extract_color(string)
        return r+dr,g+dg,b+db
      end
    },
    hsl = {
      get = function(string)
        local r, g, b = extract_color(string)
        return RGB2HSL(r,g,b)
      end,
      add = function(string, dh, ds, dl)
        local r, g, b = extract_color(string)
        local h, s, l = RGB2HSL(r,g,b)
        return lnlib.math.modloop(h+dh,0,255),lnlib.math.clamp(s+ds,0,255),lnlib.math.clamp(l+dl,0,255)
      end
    }
  },

  math = {
    clamp = function(n,min,max)
      return math.min(math.max(n,min),max)
    end,
    modloop = function(n,min,max)
      return min + ((n-min) % (max-min))
    end,
    modbounce = function(n,min,max)
      local interval = max-min
      local a = (n-min) % (2*interval)
      if a>interval then a = interval*2-a end
      return min+a
    end,
    log = function(base,n)
      return math.log(n)/math.log(base)
    end,
    sgn = function(n)
      return n<0 and -1 or 1
    end,
    round = function(num, idp)
      local bracket = 1 / 10^(idp or 0)
      return math.floor(num/bracket + lnlib.math.sgn(num) * 0.5) * bracket
    end,
    random = function(...)
      local ret
      if select("#",...) == 0 then
        ret = math.random() -- [0-1] float
      elseif select("#",...) == 1 then
        ret = select(1,...)*math.random() -- [0-a] float instead of [1-a] int
      else
        ret = select(1,...) + (select(2,...)-select(1,...))*math.random() -- [a-b] float instead of [a-b] int
      end
      return lnlib.math.round(ret, 4)
    end,
    lerp = function(time, val1, val2)
      if type(val1) == "string" and type(val2) == "string" then
        local c1 = val1:match("&H%x%x%x%x%x%x&")
        local c2 = val2:match("&H%x%x%x%x%x%x&")
        local a1 = val1:match("&H%x%x&")
        local a2 = val2:match("&H%x%x&")
        if c1 and c2 then
          return util.interpolate_color(time, c1, c2)
        elseif a1 and a2 then
          return util.interpolate_alpha(time, a1, a2)
        else
          error("lerp between mismatched or invalid color/alpha strings")
        end
      elseif type(val2) == "number" and type(val2) == "number" then
        return util.interpolate(time, val1, val2)
      else
        -- herp derp lerp
        error("lerp between mismatched variable types")
      end
    end,
    xerp = function(time, val1, val2, accel)
      local amount = math.pow(time, accel or 1);
      return lnlib.math.lerp(amount, val1, val2);
    end
  },

  subs = {

  },

  debug = {
    prog = function(n)
      aegisub.progress.set(n*100)
      return ""
    end
  },

  shapes = {
    shift = function(str,x,y)
      return shiftDrawing(str,x,y)
    end,
    roundedRectangle = function(width, height, rounding) -- centering breaks if rounding exceeds width or height, this should not happen though since only up to half of width/height makes sense
      local hr = math.floor(rounding/2+0.5)
      local formatstr = "m %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d"
      local x0, y0, x1, y1, x2, y2, x3, y3 = 0, 0, width, 0, width, height, 0, height
      return formatstr:format(x0+rounding, y0, x1-rounding, y1, x1-hr, y1, x1, y1+hr, x1, y1+rounding, x2, y2-rounding, x2, y2-hr, x2-hr, y2, x2-rounding, y2, x3+rounding, y3, x3+hr, y3, x3, y3-hr, x3, y3-rounding, x0, y0+rounding, x0, y0+hr, x0+hr, y0, x0+rounding, y0)
    end,
    rectangle = function(width, height)
      local formatstr = "m %d %d l %d %d %d %d %d %d %d %d"
      local x0, y0, x1, y1, x2, y2, x3, y3 = 0, 0, width, 0, width, height, 0, height
      return formatstr:format(x0, y0, x1, y1, x2, y2, x3, y3, x0, y0)
    end,
    circle = function(radius, segments) -- makes a properly centered approximation of a circle of r=radius (3 segments is particularly useful, as it looks almost perfect and is harder to calculate than 4 without letting this code do the math)
      segments = lnlib.math.round(math.max(2, segments or 3))
      radius = lnlib.math.round(radius)
      local blen = (4/3)*math.tan(math.pi/(2*segments))
      local minX, minY, maxX, maxY = -1, -1, 1, 1
      local phi = 0
      local x0, y0 = math.sin(phi), -math.cos(phi)
      local strTab = {("m %d %d"):format(lnlib.math.round(x0*radius)+radius, lnlib.math.round(y0*radius)+radius)} -- the drawing is contained down and right of 0,0 as usual, and rounding is done before moving to retain symmetry
      local bx0, by0, x1, y1, bx1, by1
      for i=0,segments do
        bx0, by0 = x0 + math.cos(phi)*blen, y0 + math.sin(phi)*blen  -- d/dx sin = cos, d/dx -cos = sin
        phi = i*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        bx1, by1 = x1 - math.cos(phi)*blen, y1 - math.sin(phi)*blen  -- this one goes backwards
        table.insert(strTab, ("b %d %d %d %d %d %d"):format(lnlib.math.round(bx0*radius)+radius, lnlib.math.round(by0*radius)+radius, lnlib.math.round(bx1*radius)+radius, lnlib.math.round(by1*radius)+radius, lnlib.math.round(x1*radius)+radius, lnlib.math.round(y1*radius)+radius))

        if bx0 < -1 or bx1 < -1 then -- this all is necessary for segments=2 and segments=3
          minX = math.min(bx0, bx1)
        end
        if by0 < -1 or by1 < -1 then
          minY = math.min(by0, by1)
        end
        if bx0 > 1 or bx1 > 1 then
          maxX = math.max(bx0, bx1)
        end
        if by0 > 1 or by1 > 1 then
          maxY = math.max(by0, by1)
        end

        x0, y0 = x1, y1
      end
      if minX < -1 or minY < -1 or maxX > 1 or maxY > 1 then
        local shiftX = lnlib.math.round((-minX-1 + maxX-1)/2*radius)
        local shiftY = lnlib.math.round((-minY-1 + maxY-1)/2*radius)
        for i,str in ipairs(strTab) do
          strTab[i] = shiftDrawing(str, shiftX, shiftY)
        end
      end
      return table.concat(strTab, " ")
    end,
    triangle = function(side_length) -- makes an equilateral triangle (please keep side_length even)
      local formatstr = "m %d %d l %d %d %d %d %d %d"
      local h = math.sqrt(3)/2*side_length
      local x0, y0, x1, y1, x2, y2 = 0, h, side_length, h, side_length/2, 0
      return formatstr:format(x0, y0, x1, y1, x2, y2, x0, y0)
    end,
    gear = function(r1, r2, r3, n, t, tt1, tt2) -- inner radius, middle radius, outer radius, number of teeth, thickness of teeth at base (0-1 for 0-100% of max), middle (0-1 for 0-100% of max), and top land (0-1 for 0-100% of t)
      r1 = lnlib.math.round(r1)
      r2 = lnlib.math.round(r2)
      r3 = lnlib.math.round(r3)
      local segments = lnlib.math.round(n)
      local blen = (4/3)*math.tan(math.pi*(1-t)/(2*segments))
      local minX, minY, maxX, maxY = -1, -1, 1, 1
      local phi = 0
      local x0, y0 = math.sin(phi), -math.cos(phi)
      local strTab = {("m %d %d"):format(lnlib.math.round(x0*r1), lnlib.math.round(y0*r1))} -- the drawing is centered on 0,0 because my brain hurts
      local bx0, by0, x1, y1, bx1, by1
      for i=0,segments do
        bx0, by0 = x0 + math.cos(phi)*blen, y0 + math.sin(phi)*blen  -- d/dx sin = cos, d/dx -cos = sin
        phi = (i-t)*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        bx1, by1 = x1 - math.cos(phi)*blen, y1 - math.sin(phi)*blen  -- this one goes backwards
        table.insert(strTab, ("b %d %d %d %d %d %d"):format(lnlib.math.round(bx0*r1), lnlib.math.round(by0*r1), lnlib.math.round(bx1*r1), lnlib.math.round(by1*r1), lnlib.math.round(x1*r1), lnlib.math.round(y1*r1))) 
        
        phi = (i-t/2-t*tt1/2)*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        table.insert(strTab, ("l %d %d"):format(lnlib.math.round(x1*r2), lnlib.math.round(y1*r2)))
        
        phi = (i-t/2-t*tt2/2)*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        table.insert(strTab, ("l %d %d"):format(lnlib.math.round(x1*r3), lnlib.math.round(y1*r3)))
        
        phi = (i-t/2+t*tt2/2)*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        table.insert(strTab, ("l %d %d"):format(lnlib.math.round(x1*r3), lnlib.math.round(y1*r3)))
        
        phi = (i-t/2+t*tt1/2)*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        table.insert(strTab, ("l %d %d"):format(lnlib.math.round(x1*r2), lnlib.math.round(y1*r2)))
        phi = i*2*math.pi/segments
        x1, y1 = math.sin(phi), -math.cos(phi)
        table.insert(strTab, ("l %d %d"):format(lnlib.math.round(x1*r1), lnlib.math.round(y1*r1)))
        x0, y0 = x1, y1
      end
      return table.concat(strTab, " ")
    end,
    star = "m 10 0 l 7 7 l 0 8 l 5 13 l 4 20 l 10 16 l 16 20 l 15 13 l 20 8 l 13 7 l 10 0 ",
    heart = "m 12 4 b 15 0 20 1 21 4 b 24 12 15 15 12 19 b 9 15 0 12 3 4 b 4 1 10 0 12 4 ",
    twinkle1 = "m 10 0 b 10 7 7 10 0 10 b 7 10 10 13 10 20 b 10 13 13 10 20 10 b 13 10 10 7 10 0 ",
    twinkle2 = "m 10 0 b 10 5 5 10 0 10 b 5 10 10 15 10 20 b 10 15 15 10 20 10 b 15 10 10 5 10 0 ",
    twinkle3 = "m 10 0 b 10 3 3 10 0 10 b 3 10 10 17 10 20 b 10 17 17 10 20 10 b 17 10 10 3 10 0 ",
    snowflake = "m 28 30 l 23 28 l 23 26 l 22 26 l 21 26 l 19 25 l 20 18 l 19 16 l 18 17 l 17 24 l 16 23 l 16 18 l 15 16 l 14 22 l 13 22 l 14 16 l 14 14 l 12 21 l 11 20 l 13 12 l 12 10 l 9 13 l 10 20 l 7 18 l 6 16 l 4 14 l 1 16 l 1 19 l 3 21 l 6 20 l 9 21 l 2 25 l 2 28 l 4 28 l 10 22 l 11 23 l 7 28 l 8 28 l 12 23 l 13 24 l 9 29 l 11 28 l 15 25 l 16 25 l 11 30 l 10 31 l 12 31 l 18 27 l 20 28 l 20 29 l 21 30 l 23 29 l 27 32 m 30 34 l 35 36 l 35 38 l 36 38 l 37 38 l 39 39 l 38 46 l 39 48 l 40 46 l 42 40 l 42 41 l 42 46 l 42 47 l 44 42 l 45 42 l 43 48 l 43 49 l 46 43 l 47 43 l 44 51 l 47 53 l 49 51 l 48 44 l 51 46 l 52 48 l 54 50 l 58 48 l 57 45 l 55 43 l 51 43 l 49 42 l 55 39 l 56 36 l 53 36 l 48 41 l 47 41 l 51 35 l 50 36 l 46 40 l 45 40 l 49 35 l 48 36 l 43 39 l 42 38 l 47 34 l 48 33 l 46 32 l 40 37 l 38 36 l 38 35 l 37 34 l 36 35 l 31 32 m 28 30 l 28 25 l 27 24 l 27 23 l 28 22 l 28 20 l 21 17 l 20 15 l 22 15 l 28 17 l 28 16 l 23 14 l 22 13 l 28 14 l 28 13 l 22 12 l 21 11 l 28 12 l 28 11 l 20 9 l 19 7 l 22 6 l 28 10 l 28 7 l 26 5 l 26 2 l 29 0 l 32 2 l 32 5 l 30 7 l 30 10 l 36 6 l 39 7 l 38 9 l 30 11 l 30 12 l 37 11 l 36 12 l 30 13 l 30 14 l 36 13 l 35 14 l 30 16 l 30 17 l 36 15 l 38 15 l 37 17 l 30 20 l 30 22 l 31 23 l 31 24 l 30 25 l 30 30 m 30 34 l 30 39 l 31 40 l 31 41 l 30 42 l 30 44 l 37 47 l 38 49 l 36 49 l 30 47 l 30 48 l 35 50 l 36 51 l 30 50 l 30 51 l 36 52 l 37 53 l 30 52 l 30 53 l 38 55 l 39 57 l 36 58 l 30 54 l 30 57 l 32 59 l 32 62 l 29 64 l 26 62 l 26 59 l 28 57 l 28 54 l 22 58 l 19 57 l 20 55 l 28 53 l 28 52 l 21 53 l 22 52 l 28 51 l 28 50 l 22 51 l 23 50 l 28 48 l 28 47 l 22 49 l 20 49 l 21 47 l 28 44 l 28 42 l 27 41 l 27 40 l 28 39 l 28 34 m 30 30 l 35 28 l 35 26 l 36 26 l 37 26 l 39 25 l 38 18 l 39 16 l 40 17 l 41 24 l 42 23 l 42 18 l 43 16 l 44 22 l 45 22 l 44 16 l 44 14 l 46 21 l 47 20 l 45 12 l 46 10 l 49 13 l 48 20 l 51 18 l 52 16 l 54 14 l 57 16 l 57 19 l 55 21 l 52 20 l 49 21 l 56 25 l 56 28 l 54 28 l 48 22 l 47 23 l 51 28 l 50 28 l 46 23 l 45 24 l 49 29 l 47 28 l 43 25 l 42 25 l 47 30 l 48 31 l 46 31 l 40 27 l 38 28 l 38 29 l 37 30 l 35 29 l 31 32 m 28 34 l 23 36 l 23 38 l 22 38 l 21 38 l 19 39 l 20 46 l 19 48 l 18 46 l 16 40 l 16 41 l 16 46 l 16 47 l 14 42 l 13 42 l 15 48 l 15 49 l 12 43 l 11 43 l 14 51 l 11 53 l 9 51 l 10 44 l 7 46 l 6 48 l 4 50 l 0 48 l 1 45 l 3 43 l 7 43 l 9 42 l 3 39 l 2 36 l 5 36 l 10 41 l 11 41 l 7 35 l 8 36 l 12 40 l 13 40 l 9 35 l 10 36 l 15 39 l 16 38 l 11 34 l 10 33 l 12 32 l 18 37 l 20 36 l 20 35 l 21 34 l 22 35 l 27 32 ",
    stolengleam = "m 30 23 b 24 23 24 33 30 33 b 36 33 37 23 30 23 m 35 27 l 61 28 l 35 29 m 26 27 l 0 28 l 26 29 m 29 23 l 30 0 l 31 23 m 29 33 l 30 57 l 31 33 "
  }
}

return lnlib
