#!/usr/bin/env bash
# Gera os nos de animacao do Remanescentes em 42/media/AnimSets/zombie.
# Uso (na pasta do mod): bash tools/gen_animsets.sh
# Regra do jogo (AnimNode.compareSelectionConditions): vence o no com maior
# m_ConditionPriority que tenha todas as condicoes verdadeiras. Vanilla usa ate 10.
set -e
A="$(dirname "$0")/../42/media/AnimSets/zombie"
rm -f "$A"/*/Rem*.xml
node() { # arquivo nome anim prioridade speedscale condicoes(Nome:TIPO:valor)...
  local f=$1 n=$2 a=$3 p=$4 s=$5; shift 5
  mkdir -p "$(dirname "$f")"
  { echo '<?xml version="1.0" encoding="utf-8"?>'; echo '<animNode>'
    echo "	<m_Name>$n</m_Name>"; echo "	<m_AnimName>$a</m_AnimName>"
    echo "	<m_ConditionPriority>$p</m_ConditionPriority>"; echo "	<m_BlendTime>0.25</m_BlendTime>"; echo "	<m_SpeedScale>$s</m_SpeedScale>"
    for c in "$@"; do IFS=: read cn ct cv <<<"$c"
      printf '\t<m_Conditions>\n\t\t<m_Name>%s</m_Name>\n\t\t<m_Type>%s</m_Type>\n\t\t<m_Value>%s</m_Value>\n\t</m_Conditions>\n' "$cn" "$ct" "$cv"; done
    echo '</animNode>'; } > "$f"; }
NPC=RemNPC:BOOL:true
# ---- sobreviventes parados
node $A/idle/RemIdle1H.xml       RemIdle1H       Bob_Idle             50 1.0 $NPC RemWeapon:STRING:1h
node $A/idle/RemIdleBat.xml      RemIdleBat      Bob_IdleBat          50 1.0 $NPC RemWeapon:STRING:bat
node $A/idle/RemIdleSneak1H.xml  RemIdleSneak1H  Bob_IdleSneak        55 1.0 $NPC RemWeapon:STRING:1h  RemSneak:BOOL:true
node $A/idle/RemIdleSneakBat.xml RemIdleSneakBat Bob_IdleSneak_Bat    55 1.0 $NPC RemWeapon:STRING:bat RemSneak:BOOL:true
node $A/idle/RemAttack1H.xml     RemAttack1H     Bob_Attack1Hand01_Hit 60 1.0 $NPC RemWeapon:STRING:1h  RemAttack:BOOL:true
node $A/idle/RemAttackBat.xml    RemAttackBat    Bob_AttackBat01_Hit  60 1.0 $NPC RemWeapon:STRING:bat RemAttack:BOOL:true
# ---- sobreviventes andando (root motion da animacao define a velocidade)
for st in pathfind walktoward; do
node $A/$st/RemWalk1H.xml       RemWalk1H_$st       Bob_Walk          50 1.0 $NPC RemWeapon:STRING:1h
node $A/$st/RemWalkBat.xml      RemWalkBat_$st      Bob_WalkBat       50 1.0 $NPC RemWeapon:STRING:bat
node $A/$st/RemRun1H.xml        RemRun1H_$st        Bob_Run           55 1.0 $NPC RemWeapon:STRING:1h  RemRun:BOOL:true
node $A/$st/RemRunBat.xml       RemRunBat_$st       Bob_RunBat        55 1.0 $NPC RemWeapon:STRING:bat RemRun:BOOL:true
node $A/$st/RemSneak1H.xml      RemSneak1H_$st      Bob_WalkSneak     55 1.0 $NPC RemWeapon:STRING:1h  RemSneak:BOOL:true
node $A/$st/RemSneakBat.xml     RemSneakBat_$st     Bob_WalkSneak_Bat 55 1.0 $NPC RemWeapon:STRING:bat RemSneak:BOOL:true
done
# ---- sobrevivente levando golpe (acima de tudo)
for st in idle pathfind walktoward; do
node $A/$st/RemHitReact.xml RemHitReact_$st Bob_HitReact_01 65 1.0 $NPC RemHit:BOOL:true
done
# ---- zumbis comuns atacando um sobrevivente (visual; o dano e aplicado em Lua)
for st in idle pathfind walktoward; do
node $A/$st/RemZombieAttack.xml RemZombieAttack_$st Zombie_Idle_Lunge 60 1.0 RemZAttack:BOOL:true
done
echo "gerados: $(ls "$A"/*/Rem*.xml | wc -l) nos"
