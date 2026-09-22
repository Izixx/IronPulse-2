# Widget d'écran d'accueil (optionnel)

Le code du widget est fourni dans ce dossier, mais **la cible n'est pas
construite par défaut**. Ce n'est pas un oubli : un widget a besoin d'un
**App Group** pour lire les données de l'app, et les App Groups ne sont pas
disponibles avec un Apple ID gratuit.

Or une extension non signable fait échouer l'installation Sideloadly : il vaut
mieux une app qui s'installe qu'un widget qui bloque tout.

## Ce qui est déjà en place

- `Widget/MuscuLogWidget.swift` : petite et moyenne taille, affiche la séance
  suggérée, les muscles concernés et les stats des 7 derniers jours.
- `MuscuLog/Services/WidgetSnapshot.swift` (côté app) : écrit un petit JSON dans
  le conteneur partagé quand l'app passe en arrière-plan ou qu'une séance se
  termine. Le widget ne touche **jamais** la base SwiftData directement, pour
  éviter deux processus sur le même fichier.

## Activer le widget (compte développeur payant)

1. Dans `project.yml`, décommenter la cible `MuscuLogWidget` et ajouter à la
   cible `MuscuLog` :

   ```yaml
   dependencies:
     - target: MuscuLogWidget
       embed: true
   ```

2. Ajouter la capacité **App Groups** aux deux cibles, avec l'identifiant :

   ```
   group.com.example.musculog
   ```

   (ou changez `WidgetSnapshot.appGroupIdentifier` et mettez la même valeur).

3. Régénérer le projet et reconstruire :

   ```bash
   xcodegen generate
   ```

4. Dans Sideloadly, cocher `--entitlements` si vous signez avec un compte
   payant, puis relancer la CI pour récupérer un nouveau `.ipa`.

## Sans compte payant

Le widget reste indisponible, mais tout le reste de l'app fonctionne :
le fichier JSON est simplement écrit dans un domaine isolé que personne ne lit.
Aucun crash, aucune erreur.
