#!/bin/bash
# Copia para game/assets/third_party/ninja-adventure/ SO os arquivos do MVP (lista abaixo).
# Uso, da raiz do repositorio: docs/design/arte/pacotes/importar_ninja.sh <pasta_pacotes>
# <pasta_pacotes>/ninja/x/ vem de baixar.sh; <pasta_pacotes>/ninja/pack.zip ou NinjaAdventure_AssetPack.zip e o zip.
# So PNG, WAV e textos de licenca. Nenhum script, cena ou projeto do pacote.
set -e
R=${1:?pasta dos pacotes}
S="$R/ninja/x/Ninja Adventure - Asset Pack"
Z=$(ls "$R"/ninja/*.zip | head -1)
D=game/assets/third_party/ninja-adventure
mkdir -p "$D"
cp "$S/LICENSE.txt" "$S/README.md" "$D/"

while IFS='|' read -r src dst; do
  [ -z "$src" ] && continue
  mkdir -p "$D/$(dirname "$dst")"
  cp "$S/$src" "$D/$dst"
done <<'LISTA'
Palette.png|palette.png
Backgrounds/Tilesets/TilesetFloor.png|tilesets/tileset_floor.png
Backgrounds/Tilesets/TilesetNature.png|tilesets/tileset_nature.png
Backgrounds/Tilesets/TilesetHouse.png|tilesets/tileset_house.png
Actor/Character/Caveman/SpriteSheet.png|characters/caveman.png
Actor/Character/Cavegirl/SpriteSheet.png|characters/cavegirl.png
Actor/Monster/Reptile/Reptile.png|animals/reptile.png
Actor/Monster/Lizard/Lizard.png|animals/lizard.png
Actor/Monster/Grey Trex/SpriteSheet.png|animals/grey_trex.png
Actor/Animal/Frog/SpriteSheet.png|animals/frog.png
Actor/Animal/Chicken/SpriteSheetBrown.png|animals/chicken_brown.png
Actor/Animal/Pig/SpriteSheetPink.png|animals/pig_pink.png
Items/Treasure/LittleTreasureChest.png|items/chest_small.png
Items/Treasure/BigTreasureChest.png|items/chest_big.png
Items/Treasure/GoldCoin.png|items/coin_gold.png
Items/Food/Meat.png|items/food_meat.png
Items/Food/Fish.png|items/food_fish.png
Items/Food/Nut.png|items/food_nut.png
Items/Food/Seed1.png|items/food_seed1.png
Items/Food/Seed2.png|items/food_seed2.png
Items/Food/Seed3.png|items/food_seed3.png
Items/Food/Honey.png|items/food_honey.png
Items/Resource/Branch.png|items/res_branch.png
Items/Resource/Rock.png|items/res_rock.png
Items/Resource/Grass.png|items/res_grass.png
Items/Resource/Water.png|items/res_water.png
Items/Resource/feather.png|items/res_feather.png
Items/Tool/Axe.png|items/tool_axe.png
Items/Tool/Pickaxe.png|items/tool_pickaxe.png
Items/Tool/Shovel.png|items/tool_shovel.png
Items/Tool/Hammer.png|items/tool_hammer.png
Items/Tool/Sickle.png|items/tool_sickle.png
Ui/Theme/Theme Wood/nine_path_panel.png|ui/panel_a.png
Ui/Theme/Theme Wood/nine_path_panel_2.png|ui/panel_b.png
Ui/Theme/Theme Wood/nine_path_panel_3.png|ui/panel_c.png
Ui/Theme/Theme Wood/nine_path_panel_interior.png|ui/panel_interior.png
Ui/Theme/Theme Wood/nine_path_bg.png|ui/bg_a.png
Ui/Theme/Theme Wood/nine_path_bg_2.png|ui/bg_b.png
Ui/Theme/Theme Wood/nine_path_focus.png|ui/focus.png
Ui/Theme/Theme Wood/button_normal.png|ui/button_normal.png
Ui/Theme/Theme Wood/button_hover.png|ui/button_hover.png
Ui/Theme/Theme Wood/button_pressed.png|ui/button_pressed.png
Ui/Theme/Theme Wood/button_disabled.png|ui/button_disabled.png
Ui/Theme/Theme Wood/inventory_cell.png|ui/inventory_cell.png
Ui/Dialog/DialogBox.png|ui/dialog_box.png
Ui/Receptacle/LifeBarMiniUnder.png|ui/bar_mini_under.png
Ui/Receptacle/LifeBarMiniProgress.png|ui/bar_mini_progress.png
Ui/Receptacle/Receptacle Rectangle/BackgroundWood.png|ui/bar_rect_wood.png
Ui/Receptacle/Receptacle Rectangle/ProgressHealth.png|ui/bar_rect_health.png
Ui/Receptacle/Receptacle Rectangle/ProgressWhite.png|ui/bar_rect_white.png
Ui/Receptacle/Receptacle Sphere/BackgroundWood.png|ui/sphere_wood.png
Ui/Receptacle/Receptacle Sphere/Over.png|ui/sphere_over.png
Ui/Receptacle/Receptacle Sphere/ProgressHealth.png|ui/sphere_health.png
Ui/Receptacle/Receptacle Sphere/ProgressYellow.png|ui/sphere_yellow.png
Ui/Receptacle/Receptacle Sphere/ProgressGreen.png|ui/sphere_green.png
Ui/Receptacle/IconHeart.png|ui/icon_heart.png
Ui/Receptacle/Heart.png|ui/hearts_strip.png
Ui/Emote/emote21.png|ui/emote_exclaim.png
Ui/Emote/emote22.png|ui/emote_exclaim_red.png
Ui/Emote/emote23.png|ui/emote_question.png
Ui/Emote/emote25.png|ui/emote_question_red.png
Ui/Emote/emote27.png|ui/emote_heart.png
Ui/Emote/emote28.png|ui/emote_sleep.png
FX/Attack/Claw/SpriteSheet.png|fx/claw.png
FX/Attack/ClawDouble/SpriteSheet.png|fx/claw_double.png
FX/Attack/Cut/SpriteSheet.png|fx/cut.png
FX/Attack/SlashCurved/SpriteSheet.png|fx/slash_curved.png
FX/Smoke/Smoke/SpriteSheet.png|fx/smoke.png
FX/Particle/Rock.png|fx/particle_rock.png
FX/Particle/Grass.png|fx/particle_grass.png
FX/Particle/Leaf.png|fx/particle_leaf.png
LISTA

# sons: o WAV vai do zip (a extracao de baixar.sh nao leva audio)
python3 -I - "$Z" "$D/sounds" <<'PY'
import zipfile, sys, os
zf = zipfile.ZipFile(sys.argv[1]); dst = sys.argv[2]
mapa = {
 "Hit & Impact": ("hit", ["Hit1","Hit3","Hit5","Hit6","Impact","Impact2"]),
 "Voice": ("voice", ["Voice1","Voice2","Voice3","Voice4","Voice5","Voice6"]),
 "Whoosh & Slash": ("swing", ["Slash","Slash2","Slash3","Whoosh","Whoosh2"]),
 "Menu": ("ui", ["Accept2","Accept4","Cancel2","Move2","Move4","Menu8"]),
 "Bonus": ("pickup", ["Coin","Coin2","PowerUp1"]),
 "Magic & Skill": ("misc", ["Heal"]),
 "Alert": ("misc", ["Alert3"]),
 "Elemental": ("misc", ["Grass","Grass2"]),
}
idx = {i.filename: i for i in zf.infolist()}
n = 0
for pasta, (saida, nomes) in mapa.items():
    for nome in nomes:
        alvo = [k for k in idx if k.endswith("/Audio/Sounds/%s/%s.wav" % (pasta, nome))]
        assert len(alvo) == 1, (pasta, nome)
        os.makedirs(os.path.join(dst, saida), exist_ok=True)
        open(os.path.join(dst, saida, nome.lower() + ".wav"), "wb").write(zf.read(idx[alvo[0]])); n += 1
print("sons:", n)
PY
