# ---
# title: 21 jours plus tard
# repository: tpoisot/BIO245-modele
# auteurs:
#    - nom: Bhandari
#      prenom: Snehal
#      matricule: XXXXXXXX
#      github: snehal12b
#    - nom: Fournier
#      prenom: Rosanne
#      matricule: 20332066
#      github: rosannefournier
#    - nom: Lafontaine
#      prenom: Laurianne
#      matricule: XXXXXXXX
#      github: lauriannelafontaine
# ---

# # Introduction 

# Les maladies infectieuses sont l'une des principales menaces pour la santé de la population. Nous l'avons bien observé avec le 
# Covid19, l'isolation et les nombreux décès. De nos jours, les virus deviennent de plus en plus virulent et sont transmis facilement,
# que ça soit par goutelettes, contact ou voyagement. Les virus sont insivibles, donc il peut être difficile de prévenir l'infection.
# En prévention, il y a la vaccination qui permet de se protéger en s'immunisant contre le virus et les tests de détection pour 
# protéger les autres.

# # Présentation du modèle

# Dans cette simulation, nous avons un virus causant la mort après 3 semaines (...ebola littérature)
# Celui-ci démarre dans une population complètement saine, après qu'une personne au hasard soit infectée, il
# possède un probabilité d'infection sur ses voisins de 40% par contact direct. 

# Les individus infectés sont asymptomatique, alors nous pouvons seulement détecté l'infection avec un test de détection antigénique rapide 
# (RAT). Cependant, les tests de détections ne sont pas parfait et ont un 5% de faux négatifs. En effet, il est commun de ne pas 
# avoir de tests 100% efficaces (...article)

# Pour la prévention, il y a des vaccins 100% efficaces, seulement après 2 jours. Ce n'est pas très réaliste de la 
# vraie vie (...article)

# La stratégie de vaccination repose sur 
# 1- vacciner les cas contact : plus ciblé, moins de vaccins "gaspillés"
# 2- vacciner tout le monde : enjeu budget, mais prévention efficace...


# # Implémentation

# Dans le code, il y a le cycle du virus avec la transmission, cycle de vie et le côté santé publique.

# Budjet

# # Code pour le modèle

# ## Packages nécessaires (mettre dans project)

# Pour les graphiques
using CairoMakie            
CairoMakie.activate!(px_per_unit=6.0)

using StatsBase

# Initialisation de nombre aléatoire
import Random 
Random.seed!(2045)

# Pour donner un identifiant unique aux agents
import UUIDs
UUIDs.uuid4()

# ## Création des types

# Type d'agents
# Les agents se déplacent sur une lattice, et on doit donc suivre leur position. On doit
# savoir si ils sont infectieux, et dans ce cas, combien de jours il leur reste:

Base.@kwdef mutable struct Agent        # création de valeurs par défaut pouvant changer pendant la simulation
    x::Int64 = 0
    y::Int64 = 0
    clock::Int64 = 21                   # nombre de jours avant la mort si infecté (C4)
    infectious::Bool = false            # agent sein par défaut
    vaccinated::Bool = false            # savoir si agent immunisé par vaccin (C6)
    id::UUIDs.UUID = UUIDs.uuid4()      # identifiant unique généré automatiquement
end

# Type paysage
# Définit les limites de la grille où les agents se déplacent
# Ici, c'est une grille de -50 à 50 dans les deux directions, donc 100x100 = 10 000 cases au total (C1)

Base.@kwdef mutable struct Landscape
    xmin::Int64 = -25
    xmax::Int64 = 25
    ymin::Int64 = -25
    ymax::Int64 = 25
end

# Nous allons maintenant créer un paysage de départ:

L = Landscape(xmin=-50, xmax=50, ymin=-50, ymax=50)

# ## Création de nouvelles fonctions

# Création d'agents aléatoires

# Il existe une fonction pour faire ceci dans _Julia_: `rand`. Pour que notre code
# soit facile a comprendre, nous allons donc ajouter une méthode à cette fonction:

Random.rand(::Type{Agent}, L::Landscape) = Agent(x=rand(L.xmin:L.xmax), y=rand(L.ymin:L.ymax))
Random.rand(::Type{Agent}, L::Landscape, n::Int64) = [rand(Agent, L) for _ in 1:n]

# Cette fonction nous permet donc de générer un nouvel agent dans un paysage:

# rand(Agent, L)

# Mais aussi de générer plusieurs agents:

# rand(Agent, L, 3)

# Fonction du déplacement des agents dans le paysage
# Puisque la position de l'agent va changer, notre fonction se termine par `!`:

function move!(A::Agent, L::Landscape; torus=true)
    A.x += rand(-1:1)
    A.y += rand(-1:1)
    if torus
        A.y = A.y < L.ymin ? L.ymax : A.y
        A.x = A.x < L.xmin ? L.xmax : A.x
        A.y = A.y > L.ymax ? L.ymin : A.y
        A.x = A.x > L.xmax ? L.xmin : A.x
    else
        A.y = A.y < L.ymin ? L.ymin : A.y
        A.x = A.x < L.xmin ? L.xmin : A.x
        A.y = A.y > L.ymax ? L.ymax : A.y
        A.x = A.x > L.xmax ? L.xmax : A.x
    end
    return A
end

# Nous pouvons maintenant définir des fonctions qui vont nous permettre de nous simplifier la rédaction du code

# Vérifier si un agent est infectieux

isinfectious(agent::Agent) = agent.infectious

# Vérifier si un agent est sain

ishealthy(agent::Agent) = !isinfectious(agent)

# Vérifier si un agent est vacciné

isvaccined(agent::Agent = agent.vaccinated)

# Vérifier si un agent est un attente de l'efficacité du vaccin (C7)

ispending(agent::Agent = agent.vaccin_clock)

# On peut maintenant définir une fonction pour prendre uniquement les agents qui
# sont infectieux dans une population. Pour que ce soit clair, nous allons créer
# un _alias_, `Population`, qui voudra dire `Vector{Agent}`:

const Population = Vector{Agent}
infectious(pop::Population) = filter(isinfectious, pop)     # retourne les agents malades
healthy(pop::Population) = filter(ishealthy, pop)           # retourne les agents sains

# Nous allons enfin écrire une fonction pour trouver l'ensemble des agents d'une
# population qui sont dans la même cellule qu'un agent: retourne les agents qui ont exactement
# les mêmes coordonées que l'agent cible (contatcs potentiels)

incell(target::Agent, pop::Population) = filter(ag -> (ag.x, ag.y) == (target.x, target.y), pop)

# ## Gestion vaccins

# Lorsque l'on administre un vaccin, il y a un temps avant que celui-ci devienne efficace.
# Ici, c'est 2 jours (C7)

function administrer_vaccin!(agent::Agent)
    agent.vaccin_clock = 2
    return agent
end 

# ## Gestion budget

# ## Paramètres initiaux

# # Initialisation de la simulation

# Population initiale:

population = Population(L, 3750)        # 3750 étant la taille de la population (C2)

# Choisir au hasard dans la population un infecté (cas index) C5 :

rand(population).infectious = true

# Nous initialisons la simulation au temps 0, et nous allons la laisser se
# dérouler au plus 1000 pas de temps:

tick = 0
maxlength = 2000

# Pour étudier les résultats de la simulation, nous allons stocker la taille de
# populations à chaque pas de temps:

S = zeros(Int64, maxlength);        # série temporelle sain
I = zeros(Int64, maxlength);        # série temporelle infectieux

# Événement d'infection : 
# Mais nous allons aussi stocker tous les évènements d'infection qui ont lieu
# pendant la simulation

struct InfectionEvent
    time::Int64
    from::UUIDs.UUID
    to::UUIDs.UUID
    x::Int64
    y::Int64
end

# Liste vide qui va se remplir durant la simulation pour "stocker"

events = InfectionEvent[]

# Notez qu'on a contraint notre vecteur `events` a ne contenir _que_ des valeurs
# du bon type, et que nos `InfectionEvent` sont immutables.

# ## Simulation 

# La boucle tourne tant qu'il y a des infectieux et que le temps max n'est pas atteint

while (length(infectious(population)) != 0) & (tick < maxlength)

    ## On spécifie que nous utilisons les variables définies plus haut
    global tick, population

    tick += 1

    ## Mouvement : les agents bougent d'une case
    for agent in population
        move!(agent, L; torus=false)
    end

    ## Infection : les infectieux ont 40% d'infecter un voisin sain au hasard (C3)
    for agent in Random.shuffle(infectious(population))
        neighbors = healthy(incell(agent, population))
        for neighbor in neighbors
            if rand() <= 0.4
                neighbor.infectious = true
                push!(events, InfectionEvent(tick, agent.id, neighbor.id, agent.x, agent.y))
            end
        end
    end

    ## Changement de la survie : -1 jour pour chaque infectieux
    for agent in infectious(population)
        agent.clock -= 1
    end

    ## Enlever les morts : on retire ceux qui n'ont plus de jours
    population = filter(x -> x.clock > 0, population)

    ## Enregistrement dans la série temporelle respective
    S[tick] = length(healthy(population))
    I[tick] = length(infectious(population))

end

# ## Analyse des résultats

# ### Série temporelle

# Avant toute chose, nous allons couper les séries temporelles au moment de la
# dernière génération:

S = S[1:tick];
I = I[1:tick];

# 

f = Figure()
ax = Axis(f[1, 1]; xlabel="Génération", ylabel="Population")
stairs!(ax, 1:tick, S, label="Susceptibles", color=:black)
stairs!(ax, 1:tick, I, label="Infectieux", color=:red)
axislegend(ax)
current_figure()

# ### Nombre de cas par individu infectieux

# Nous allons ensuite observer la distribution du nombre de cas créés par chaque
# individus. Pour ceci, nous devons prendre le contenu de `events`, et vérifier
# combien de fois chaque individu est représenté dans le champ `from`:

infxn_by_uuid = countmap([event.from for event in events]);

# La commande `countmap` renvoie un dictionnaire, qui associe chaque UUID au
# nombre de fois ou il apparaît:

# Notez que ceci nous indique combien d'individus ont été infectieux au total:

length(infxn_by_uuid)

# Pour savoir combien de fois chaque nombre d'infections apparaît, il faut
# utiliser `countmap` une deuxième fois:

nb_inxfn = countmap(values(infxn_by_uuid))

# On peut maintenant visualiser ces données:

f = Figure()
ax = Axis(f[1, 1]; xlabel="Nombre d'infections", ylabel="Nombre d'agents")
scatterlines!(ax, [get(nb_inxfn, i, 0) for i in Base.OneTo(maximum(keys(nb_inxfn)))], color=:black)
f

# ### Hotspots

# Nous allons enfin nous intéresser à la propagation spatio-temporelle de
# l'épidémie. Pour ceci, nous allons extraire l'information sur le temps et la
# position de chaque infection:

t = [event.time for event in events];
pos = [(event.x, event.y) for event in events];

#

f = Figure()
ax = Axis(f[1, 1]; aspect=1, backgroundcolor=:grey97)
hm = scatter!(ax, pos, color=t, colormap=:navia, strokecolor=:black, strokewidth=1, colorrange=(0, tick), markersize=6)
Colorbar(f[1, 2], hm, label="Time of infection")
hidedecorations!(ax)
current_figure()

# # Figures supplémentaires

# Visualisation des infections sur l'axe x

scatter(t, first.(pos), color=:black, alpha=0.5)

# et y

scatter(t, last.(pos), color=:black, alpha=0.5)

# Tous les fichiers dans le dossier `code` peuvent être ajoutés au travail
# final. C'est par exemple utile pour déclarer l'ensemble des fonctions du
# modèle hors du document principal.

# Le contenu des fichiers est inclus avec `include("code/nom_fichier.jl")`.

# Attention! Il faut que le code soit inclus au bon endroit (avant que les
# fonctions déclarées soient appellées).

include("code/01_test.jl")

# ## Une autre section

"""
    foo(x, y)

Cette fonction ne fait rien.
"""
function foo(x, y)
    ## Cette ligne est un commentaire
    return nothing
end

# # Présentation des résultats

# La figure suivante représente des valeurs aléatoires:

hist(randn(1000), color=:grey80)

# # Discussion

# On peut aussi citer des références dans le document `references.bib`, qui doit
# être au format BibTeX. Les références peuvent être citées dans le texte avec
# `@` suivi de la clé de citation. Par exemple: @ermentrout1993cellular -- la
# bibliographie sera ajoutée automatiquement à la fin du document.

# Le format de la bibliographie est American Physics Society, et les références
# seront correctement présentées dans ce format. Vous ne devez/pouvez pas éditer
# la bibliographie à la main.
