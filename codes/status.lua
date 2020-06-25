require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for status IDs according to internal files
codes.STATUS, codes.STATUS_NAMES = enum.register({
    'None',         -- Called "-" internally
    'Sleep',
    'Sleepless',    -- Alt: Won't get sleepy
    'Nightmare',    -- Alt: Caught in a nightmare
    'Yawning',
    'Napping',
    'LowHP',        -- Alt: Low HP! Situation critical!
    'Burn',         -- Alt: Burned
    'Poisoned',
    'BadlyPoisoned',
    'Paralysis',    -- Alt: Paralyzed
    'Identifying',
    'Frozen',
    'ShadowHold',   -- Alt: Immobilized
    'Wrap',         -- Alt: Wrapped around foe
    'Wrapped',      -- Alt: Wrapped by foe
    'Ingrain',      -- Alt: Using Ingrain
    'Petrified',
    'Constriction', -- Alt: Being squeezed
    'Famished',     -- Alt: About to drop from hunger
    'Cringe',       -- Alt: Cringing
    'Confused',
    'Paused',       -- Alt: Pausing
    'Cowering',
    'Taunted',
    'Encore',       -- Alt: Afflicted with Encore
    'Infatuated',
    'DoubleSpeed',  -- Alt: Sped up
    'Bide',         -- Alt: Biding
    'SolarBeam',    -- Alt: Charging SolarBeam
    'SkyAttack',    -- Alt: Charging Sky Attack
    'RazorWind',    -- Alt: Charging Razor Wind
    'FocusPunch',   -- Alt: Charging Focus Punch
    'SkullBash',    -- Alt: Charging Skull Bash
    'Flying',       -- Alt: Flying high up
    'Bouncing',
    'Diving',       -- Alt: Hiding underwater
    'Digging',      -- Alt: Burrowing underground
    'Charging',     -- Alt: Using Charge
    'Enraged',      -- Alt: Shaking with rage
    'ShadowForce',  -- Alt: Hiding among shadows
    'HalfSpeed',    -- Alt: Slowed down
    'Reflect',      -- Alt: Protected by Reflect
    'Safeguard',    -- Alt: Protected by Safeguard
    'LightScreen',  -- Alt: Protected by Light Screen
    'Counter',      -- Alt: Ready to counter
    'MagicCoat',    -- Alt: Protected by Magic Coat
    'Wish',         -- Alt: Making a wish
    'Protect',      -- Alt: Protecting itself
    'MirrorCoat',   -- Alt: Protected by Mirror Coat
    'Enduring',     -- Alt: Set to endure
    'MiniCounter',  -- Alt: Ready to deliver mini counters
    'MirrorMove',   -- Alt: Using Mirror Move
    'Conversion2',  -- Alt Using Conversion 2
    'VitalThrow',   -- Alt: Ready to use Vital Throw
    'Mist',         -- Alt: Protected by Mist
    'MetalBurst',   -- Alt: Protected by Metal Burst
    'AquaRing',     -- Alt: Cloaked by Aqua Ring
    'LuckyChant',   -- Alt: Lucky Chant in effect
    'Weakened',
    'Cursed',
    'Decoy',
    'Snatch',       -- Alt: Ready to snatch moves
    'GastroAcid',   -- Alt: Drenched with Gastro Acid
    'HealBlock',    -- Alt: Prevented from healing
    'Embargo',      -- Alt: Under Embargo
    'HungryPal',    -- Alt: Immobilized by hunger
    'LeechSeed',    -- Alt: Afflicted with Leech Seed
    'DestinyBond',  -- Alt: Using Destiny Bond
    'PoweredUp',
    'SureShot',     -- Alt: Total accuracy for moves
    'Whiffer',      -- Alt: Afflicted with Smokescreen
    'SetDamage',    -- Alt: Inflicts set damage
    'FocusEnergy',  -- Alt: Enhanced critical-hit rate
    'Unnamed0x4A',  -- Called "-" internally
    'LongToss',     -- Alt: Throws thrown items far
    'Pierce',       -- Alt: Pierces walls w/ thrown items
    'Unnamed0x4D',
    'Invisible',
    'Transformed',  -- Alt: Transformed Pokemon
    'Mobile',       -- Alt: Travel anywhere
    'Slip',         -- Alt: Walk on water
    'Unnamed0x52',
    'Blinker',      -- Alt: Blinded
    'CrossEyed',    -- Alt: Hallucinating
    'Eyedrops',     -- Alt: Seeing the unseeable
    'Dropeye',      -- Alt: Poor vision
    'Unnamed0x57',
    'Muzzled',      -- Alt: Unable to use its mouth
    'Unnamed0x59',
    'MiracleEye',   -- Alt: Exposed by Miracle Eye
    'Unnamed0x5B',
    'MagnetRise',   -- Alt: Levitating with Magnet Rise
    'Stockpiling',
    'PowerEars',    -- Alt: Can locate other Pokemon
    'Scanning',     -- Alt: Can locate items
    'Grudge',       -- Alt: Bearing a grudge
    'Exposed',      -- Alt: Exposed to sight
    'Terrified',
    'PerishSong',   -- Alt: Received Perish Song
    'DoubledAttack',    -- Alt: Has sped-up attacks
    'StairSpotter', -- Alt: Can locate stairs
}, 0, 'status')