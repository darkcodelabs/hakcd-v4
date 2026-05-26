-- source/systems/SceneRouter.lua
--
-- Centralized scene transition. Looks up canon.scenes[scene_id] and calls
-- Noble.transition with the resolved class. Validates the target exists.
-- Logs the transition. Returns false on unknown id without crashing.
--
-- Phase 11 (v0.1.25) introduced this layer so every transition flows through
-- a single chokepoint we can later instrument (analytics, save-on-transition,
-- music crossfade hooks, etc.). Direct Noble.transition is still legal but
-- discouraged outside this file and the system-menu restore path.

SceneRouter = {}

-- transition_by_id(scene_id, args)
--   scene_id  string   canonical key into canon.scenes (e.g. 'BedroomScene')
--   args      table?   optional, passed through to Noble.transition's args slot
-- Returns true on success, false on lookup failure (with print).
function SceneRouter.transition_by_id(scene_id, args)
    if not (canon and canon.scenes) then
        print('[SceneRouter] canon.scenes missing')
        return false
    end
    local entry = canon.scenes[scene_id]
    if not entry then
        print("[SceneRouter] unknown scene_id '" .. tostring(scene_id) .. "'")
        return false
    end
    local target_class = _G[entry.class]
    if not target_class then
        print("[SceneRouter] scene class '" .. tostring(entry.class) ..
              "' not loaded -- did you forget an import?")
        return false
    end
    print("[SceneRouter] -> " .. tostring(scene_id))
    -- Noble.transition signature: (Scene, duration, holdTime, transitionType, args)
    if args then
        Noble.transition(target_class, nil, nil, nil, args)
    else
        Noble.transition(target_class)
    end
    return true
end

-- transition(scene_class, args)
--   Pass-through helper for callers that still hand us a class directly
--   (e.g. the system-menu "back to story" restore path that resolves a
--   stashed class name at run time). Behaviour matches Noble.transition
--   exactly; we just log + leave a per-transition hook point.
function SceneRouter.transition(scene_class, args)
    if not scene_class then
        print('[SceneRouter] transition called with nil class')
        return false
    end
    print('[SceneRouter] -> (class direct)')
    if args then
        Noble.transition(scene_class, nil, nil, nil, args)
    else
        Noble.transition(scene_class)
    end
    return true
end

_G.SceneRouter = SceneRouter
return SceneRouter
