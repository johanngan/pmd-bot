require 'utils.enum'

if codes == nil then
    codes = {}
end

-- Enum for trap IDs according to the order in the internal text_e.str file (US version)
codes.TRAP, codes.TRAP_NAMES = enum.register({
    'Secret',
    'MudTrap',
    'StickyTrap',
    'GrimyTrap',
    'SummonTrap',
    'PitfallTrap',
    'WarpTrap',
    'GustTrap',
    'SpinTrap',
    'SlumberTrap',
    'SlowTrap',
    'SealTrap',
    'PoisonTrap',
    'SelfdestructTrap',
    'ExplosionTrap',
    'PPZeroTrap',
    'ChestnutTrap',
    'WonderTile',
    'PokemonTrap',
    'SpikedTile',
    'StealthRock',
    'ToxicSpikes',
    'TripTrap',
    'RandomTrap',
    'GrudgeTrap',
}, 0, 'trap')