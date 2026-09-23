# MuscuLog 🏋️

Application iOS native (SwiftUI + SwiftData + Swift Charts) pour suivre ta
progression en musculation. **100 % locale** : pas de compte, pas de serveur,
pas d'iCloud, pas de notification push distante. Conçue pour être installée par
sideload depuis Windows, sans Mac.

- **Cible** : iOS 17 minimum, iPhone, portrait
- **Architecture** : MVVM (`Models` / `ViewModels` / `Views` / `Services`)
- **Persistance** : SwiftData
- **Graphiques** : Swift Charts
- **Dépendances externes** : aucune

---

## 1. Ce que fait l'app

### Onglet Accueil / Stats

- **« Quoi entraîner aujourd'hui ? »** : pour chaque groupe musculaire, le
  nombre de jours écoulés depuis sa dernière sollicitation, avec un score de
  priorité. Un muscle jamais travaillé passe devant tout, un muscle encore en
  récupération (48 h pour les petits groupes, 72 h pour les gros) est écarté.
- **Bouton « Démarrer cette séance »** : génère une séance ciblée avec un
  exercice composé par muscle à travailler.
- **Volume par groupe musculaire** : anneau (camembert) + barres + classement
  des 3 muscles les plus et les moins travaillés, filtrable sur
  **7 jours / 30 jours / depuis le début**.
- **Heatmap d'assiduité** façon GitHub (26 semaines) + séries de jours et de
  semaines consécutives.
- **Stats globales** : nombre de séances, volume total (tonnes), séries,
  répétitions, fréquence hebdomadaire, durée moyenne.

### Onglet Séance

- Démarrage libre, **recopie de la dernière séance** en un tap, ou **démarrage
  depuis la routine active** (le cycle avance tout seul).
- Ajout d'exercices avec recherche instantanée et filtres par muscle.
- **Préremplissage automatique** : quand tu ajoutes un exercice, les séries de
  la dernière fois sont recopiées (poids + reps). En salle tu confirmes ou tu
  ajustes, tu ne ressaisis pas.
- Par série : **répétitions, poids, RPE optionnel**, marquage échauffement
  (exclu de toutes les statistiques).
- Champs numériques avec boutons **− / +** larges (poids par pas de 2,5 kg,
  reps par 1) : utilisables d'une main, sans clavier.
- **Minuteur de repos** : aucun timer ne tourne dans l'app, la fin de repos est
  calculée à partir d'une date et une notification locale prévient même app
  fermée. Boutons `+15 s` et `Passer`.
- Fin de séance : résumé avec durée, volume, séries et **records battus**.

### Onglet Historique

- Séances groupées par mois, recherche par exercice ou par nom de routine.
- Heatmap d'assiduité en tête de liste.
- Chaque séance passée est **entièrement modifiable** (date, ressenti,
  exercices, séries) — utile quand on a oublié de noter une série.

### Onglet Exercices / Routines

- **67 exercices préremplis** (développé couché, squat, soulevé de terre,
  tractions, rowing, développé militaire, curl, extensions triceps, mollets,
  gainage…) avec leurs groupes musculaires et leur équipement.
- Recherche **insensible aux accents** (« developpe » trouve « Développé couché »).
- Création de ses propres exercices (nom, plusieurs groupes musculaires,
  équipement).
- **Records par exercice** : charge max, **1RM estimé** (Epley), meilleur volume
  en une séance, meilleures reps, charge conseillée pour viser 8 répétitions.
- **Courbes de progression** : charge max, 1RM estimé, volume, répétitions.
- **Routines** (Push/Pull/Legs, Haut/Bas, Full body livrées en modèle) : active
  une routine et l'app suit où tu en es dans le cycle.

### Réglages

- **Export JSON et CSV** via la feuille de partage iOS.
- Rappels d'entraînement locaux (heure choisie, répétition hebdomadaire).
- Durée de repos par défaut, notification de fin de repos, retour haptique.
- Suivi du **poids de corps** (courbe séparée, variation sur 30 jours).
- Mode sombre : rien à faire, tout est construit sur les couleurs système.
- Remise à zéro des données (avec ré-amorçage de la bibliothèque).

---

## 2. Structure du projet

```
project.yml                     # spec XcodeGen (source de vérité du projet Xcode)
.github/workflows/build.yml     # CI : tests + build IPA non signé
Support/Info.plist              # Info.plist de l'app
MuscuLog/
  App/           MuscuLogApp.swift, RootTabView.swift
  Models/        MuscleGroup, Exercise, Workout, Routine, BodyWeightEntry, Relationships
  Data/          SeedData.swift          (bibliothèque + routines types)
  ViewModels/    ActiveSessionViewModel, StatsViewModel
  Services/      ExportService, NotificationService, HealthKitService, WidgetSnapshot, Haptics
  Support/       Fitness (1RM, formatage), StatsModels (types de statistiques)
  Views/         HomeView, ActiveSessionView, HistoryView, SettingsView, …
    Components/  Components.swift, Charts.swift
MuscuLogTests/   tests du moteur de stats, de l'export et du formatage
Widget/          widget optionnel (voir Widget/README-WIDGET.md)
```

### Pourquoi XcodeGen ?

Le projet est développé sous Windows, où Xcode n'existe pas. Écrire à la main
un `.xcodeproj` (fichier `pbxproj` binaire, impossible à relire en revue) est
fragile. `project.yml` décrit le projet en YAML ; `xcodegen generate` fabrique
le `.xcodeproj` à la volée, à la maison comme dans la CI. Le `.xcodeproj` est
donc dans le `.gitignore`.

---

## 3. Compiler l'IPA depuis Windows

Aucun Mac n'est nécessaire : les runners **macOS de GitHub Actions sont
gratuits** pour un dépôt public (et disposent d'un quota généreux pour un
dépôt privé).

### Mise en place (une seule fois)

Crée d'abord le dépôt sur GitHub, **vide** (sans README ni .gitignore : ils
créeraient un conflit au premier push). Rends-le public : sur un dépôt privé,
les minutes des runners macOS sont décomptées ×10 sur le quota gratuit.

```bash
cd IronPulse-2
git init
git add .
git commit -m "App de suivi de musculation"
git remote add origin https://github.com/Izixx/IronPulse-2.git
git push -u origin master
```

Si un mauvais remote a déjà été enregistré :

```bash
git remote set-url origin https://github.com/Izixx/IronPulse-2.git
```

`Repository not found` ne veut pas dire « dépôt privé » : GitHub renvoie la même
erreur quand le dépôt **n'existe pas** ou quand le remote pointe vers un autre
nom. Vérifie l'URL du remote avant de suspecter tes identifiants.

### Récupérer l'IPA

1. Va dans l'onglet **Actions** du dépôt.
2. Le workflow **Build iOS IPA** se lance à chaque push (et manuellement via
   *Run workflow*).
3. Ouvre le run terminé → **Artifacts** → télécharge **MuscuLog-ipa**.
4. Décompresse : tu obtiens `MuscuLog.ipa`.

Le job compile en `Release` avec `CODE_SIGNING_ALLOWED=NO` : le `.ipa` n'est pas
signé, c'est **Sideloadly** qui apporte la signature à l'installation.

Un second job (**test**) compile et exécute les tests unitaires sur simulateur.
Il tourne en parallèle du build : même si un test échoue, l'IPA est quand même
produit.

---

## 4. Installer sur l'iPhone (Sideloadly, depuis Windows)

1. Installe **Sideloadly** sur le PC (sideloadly.io) et **iTunes** (version
   Apple, pas celle du Microsoft Store) pour les pilotes USB.
2. Branche l'iPhone en USB, déverrouille-le, et fais **« Se fier à cet
   ordinateur »**.
3. Glisse le `MuscuLog.ipa` dans Sideloadly.
4. Saisis ton **Apple ID** (un compte gratuit suffit).
5. **Start** : Sideloadly signe et installe.
6. Sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** →
   fais confiance à ton profil développeur.

### Apple ID gratuit vs compte payant

| | Apple ID gratuit | Compte développeur (99 $/an) |
|---|---|---|
| Signature | **7 jours**, puis réinstallation | ~1 an |
| HealthKit | ❌ | ✅ |
| Widget / App Groups | ❌ | ✅ |
| Nombre d'apps | 3 | illimité |

**Conséquence importante** : avec un Apple ID gratuit, la signature meurt au
bout de 7 jours. Au moment de réinstaller, iOS peut supprimer les données de
l'app. **Exporte régulièrement** : Réglages → *Exporter en JSON* / *en CSV*,
puis garde le fichier dans Fichiers, dans un mail ou sur un cloud.

> Astuce : côté iPhone, réinstaller par-dessus l'IPA existant (sans désinstaller
> d'abord) conserve en général le conteneur de données. Mais ne compte pas
> dessus comme seule sauvegarde.

---

## 5. Personnaliser avant de compiler

Dans `project.yml`, remplace l'identifiant de bundle par le tien (unique) :

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.tonnom.musculog
```

Il n'est **pas** nécessaire d'avoir un identifiant unique pour que Sideloadly
fonctionne (il le réécrit), mais c'est plus propre et ça évite les collisions.

---

## 6. Options réservées à un compte payant

### HealthKit (écriture des séances, lecture du poids)

Désactivé par défaut : l'entitlement `com.apple.developer.healthkit` n'existe
pas pour les Apple ID gratuits, et une extension non signable ferait échouer
Sideloadly. Tout le code est prêt dans `MuscuLog/Services/HealthKitService.swift`.

Pour l'activer :

1. Créer `Support/MuscuLog.entitlements` avec la clé
   `com.apple.developer.healthkit = true`.
2. Dans `project.yml`, décommenter :

   ```yaml
   SWIFT_ACTIVE_COMPILATION_CONDITIONS: $(inherited) HEALTHKIT_ENABLED
   CODE_SIGN_ENTITLEMENTS: Support/MuscuLog.entitlements
   ```

3. Régénérer et reconstruire.

### Widget d'écran d'accueil

Voir `Widget/README-WIDGET.md` : le code est fourni, la cible est fournie mais
commentée dans `project.yml`, car elle exige un App Group.

---

## 7. Tests

Les tests unitaires couvrent le moteur de statistiques (volume réparti par
muscle, récupération, records, 1RM, heatmap, séries d'assiduité), l'export
JSON/CSV et le formatage. Ils tournent avec l'infrastructure SwiftData
**en mémoire**, sans toucher à la base réelle.

```bash
# sur un Mac
brew install xcodegen
xcodegen generate
xcodebuild test -project MuscuLog.xcodeproj -scheme MuscuLog \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Sur Windows, il suffit de pousser ta branche : le job `test` du workflow s'en
charge et affiche les résultats dans l'onglet Actions.

---

## 8. Conventions et choix techniques

- **Échauffements exclus** de tous les calculs : volume, séries, records. Seules
  les séries de travail comptent, sinon les graphiques sont faussés.
- **Volume réparti à parts égales** entre les groupes d'un exercice : un
  développé couché (pectoraux + triceps + épaules) donne un tiers de son
  tonnage à chacun. La somme des volumes par muscle égale donc le volume total,
  ce qui rend le camembert honnête.
- **1RM estimé** par la formule d'Epley, fiable jusqu'à ~10-12 répétitions.
- **Suppression d'un exercice** : on préfère l'archivage (l'historique reste
  intact). Une suppression réelle ne supprime jamais les séances passées.
- **Séance en cours persistée** : c'est un `WorkoutSession` avec `endedAt == nil`.
  Si l'app est tuée en pleine séance, elle est retrouvée au lancement suivant.
- **Relations SwiftData** attachées explicitement des deux côtés
  (`Models/Relationships.swift`) : la mise à jour automatique de la relation
  inverse peut être différée, ce qui donne des listes vides juste après une
  insertion. Le test de présence évite les doublons quand SwiftData a déjà fait
  le travail.

---

## 9. Limites connues

- Le projet **n'a pas pu être compilé** lors de sa génération : il a été écrit
  sous Windows, sans Xcode. Le premier run de CI est le vrai compilateur. Si le
  job `build` échoue, l'erreur est explicite et corrigeable en un commit.
- Pas de tests d'interface (XCUITest) : la CI ne teste que la logique métier et
  la compilation.
- Les exercices sont en français, les unités en kilogrammes.
