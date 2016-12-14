---- HUD stuff similar to weapon/ammo pickups but for game status messages

-- This is some of the oldest TTT code, and some of the first Lua code I ever
-- wrote. It's not the greatest.

MSTACK = {}

MSTACK.msgs = {}
MSTACK.last = 0

-- Localise some libs
local table = table
local surface = surface
local draw = draw
local pairs = pairs

-- Constants for configuration
MSTACK.msgfont = "DefaultBold"

local margin = 6
local msg_width = 400

local text_width = msg_width - (margin * 3) -- three margins for a little more room

local top_y = margin
local top_x = ScrW() - margin - msg_width

local staytime = 12
local max_items = 8

local fadein = 0.1
local fadeout = 0.6

local movespeed = 2

-- Text colors to render the messages in
MSTACK.msgcolors = {
   traitor_text = COLOR_RED,
   generic_text = COLOR_WHITE,

   generic_bg = Color(0, 0, 0, 200)
};

MSTACK.rolecolors = {
   [ROLE_TRAITOR]   = Color(150, 0, 0, 200),
   [ROLE_DETECTIVE] = Color(0, 0, 150, 200),
   [ROLE_INNOCENT]  = Color(0, 50,  0, 200)
};

-- Total width we take up on screen, for other elements to read
MSTACK.width = msg_width + margin

function MSTACK:AddMessage(text, color, background_color)
   local item = {}

   item.col = table.Copy(color or self.msgcolors.generic_text)
   item.col.a_max = item.col.a

   item.bg  = table.Copy(background_color or self.msgcolors.generic_bg)
   item.bg.a_max = item.bg.a

   item.text = self:WrapText(text, text_width)
   -- Height depends on number of lines, which is equal to number of table
   -- elements of the wrapped item.text
   item.height = (#item.text * draw.GetFontHeight(self.msgfont)) + (margin * (1 + #item.text))

   item.time = CurTime()
   item.sounded = false
   item.move_y = -item.height

   -- Stagger the fading a bit
   if self.last > (item.time - 1) then
      item.time = self.last + 1 --item.time + 1
   end

   -- Insert at the top
   table.insert(self.msgs, 1, item)

   self.last = item.time
end

function MSTACK:AddRoleMessage(text, role)
   self:AddMessage(text, self.msgcolors.generic_text, self.rolecolors[role])
end

-- Oh joy, I get to write my own wrapping function. Thanks Lua!
-- Splits a string into a table of strings that are under the given width.
function MSTACK:WrapText(text, width)
   surface.SetFont(self.msgfont)

   -- Any wrapping required?
   local w, _ = surface.GetTextSize(text)
   if w <= width then
      return {text} -- Nope, but wrap in table for uniformity
   end

   local words = string.Explode(" ", text) -- No spaces means you're screwed

   local lines = {""}
   for i, wrd in pairs(words) do
      local l = #lines
      local added = lines[l] .. " " .. wrd
      w, _ = surface.GetTextSize(added)

      if w > text_width then
         -- New line needed
         table.insert(lines, wrd)
      else
         -- Safe to tack it on
         lines[l] = added
      end
   end

   return lines
end

local base_spec = {
   xalign = TEXT_ALIGN_CENTER,
   yalign = TEXT_ALIGN_TOP
};

function MSTACK:Draw(client)
   if next(self.msgs) == nil then return end -- fast empty check

   local running_y = top_y
   for k, item in pairs(self.msgs) do
      if item.time < CurTime() then
         if item.sounded == false then
            surface.PlaySound("Hud.Hint")
            item.sounded = true
         end

         -- Apply move effects to y
         local y = running_y + margin + item.move_y

         item.move_y = (item.move_y < 0) and item.move_y + movespeed or 0

         local delta = (item.time + staytime) - CurTime()
         delta = delta / staytime -- pct of staytime left

         -- Hurry up if we have too many
         if k >= max_items then
            delta = delta / 2
         end

         local alpha = 255
         -- These somewhat arcane delta and alpha equations are from gmod's
         -- HUDPickup stuff
         if delta > 1 - fadein then
            alpha = math.Clamp( (1.0 - delta) * (255 / fadein), 0, 255)
         elseif delta < fadeout then
            alpha = math.Clamp( delta * (255 / fadeout), 0, 255)
         end

         local height = item.height

         -- Background box
         draw.RoundedBox(8, top_x, y, msg_width, height, item.bg)

         -- Text
         item.col.a = math.Clamp(alpha, 0, item.col.a_max)

         local spec = base_spec
         spec.font = self.msgfont
         spec.color = item.col

         for i = 1, #item.text do
            spec.text=item.text[i]

            local tx = top_x + (msg_width / 2)
            local ty = y + margin + (i - 1) * (draw.GetFontHeight(self.msgfont) + margin)
            spec.pos={tx, ty}

            draw.TextShadow(spec, 1, alpha)
         end

         if alpha == 0 then
            self.msgs[k] = nil
         end

         running_y = y + height
      end
   end
end

-- Game state message channel
local function ReceiveGameMsg()
   local text = net.ReadString()
   local traitor_only = net.ReadBool()

   local color = traitor_only and MSTACK.msgcolors.traitor_bg or MSTACK.msgcolors.generic_bg

   print(text)

   MSTACK:AddMessage(text, color)
end
net.Receive("TTT_GameMsg", ReceiveGameMsg)

local function ReceiveCustomMsg()
   local text = net.ReadString()
   local color = net.ReadColor()

   print(text)

   MSTACK:AddMessage(text, color)
end
net.Receive("TTT_GameMsgColor", ReceiveCustomMsg)
