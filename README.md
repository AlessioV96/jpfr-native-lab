# JPFR — laboratoire natif Apple, sources 0.1.0

Ce dossier prépare un essai japonais → français avec le framework Translation d’Apple. **Les sources ne sont pas encore compilées avec Xcode et aucun résultat de traduction Apple n’est validé sur iPhone.** Les contrôles Windows portent sur les messages, les ressources et une interface simulée.

Le prototype est séparé du traducteur vidéo existant. Il n’analyse pas de vidéo, n’enregistre pas le microphone et ne lit aucune page web. Son premier objectif est de comparer quatre phrases problématiques avec le moteur Apple. Un contrôle de 24 phrases est également prévu.

## Contenu

- Application JPFRNativeLab : préparation des langues par l’interface système, choix d’une préférence qualité/rapidité, quatre contrôles prioritaires, test complet facultatif et export JSON.
- Application expérimentale JPFRSafariLab : même laboratoire et extension Safari embarquée.
- Extension JPFRNativeExtension : fenêtre de contrôle manuel et requêtes vers la partie native. La seule permission web demandée est nativeMessaging.
- Contrat partagé : version 1, identifiants corrélés, japonais et français fixés, limite de 600 scalaires et 4 096 octets. Une demande native active par processus ; annulation et rejet des réponses tardives.
- Procédure GitHub Actions : compilation sans signature sur un Mac standard, déclenchée manuellement. Deux vérifications distinctes, application seule et pont Safari.

L’application prépare les langues avant l’usage de l’extension. La session de traduction créée sans interface ne peut pas demander elle-même leur téléchargement. La préférence qualité peut revenir à une autre stratégie selon l’appareil et les langues ; le rapport ne prétend pas identifier le modèle effectif. [Initialisation Apple](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:)), [préparation des langues](https://developer.apple.com/documentation/translation/translationsession/canrequestdownloads).

Le traitement de TranslationSession est documenté comme local à l’appareil ; cette propriété ne démontre pas sa fidélité, sa vitesse ni son fonctionnement dans notre extension. [Documentation Apple](https://developer.apple.com/documentation/translation/translationsession)

## État des vérifications

Exécuté sur Windows :

- 18 vecteurs du contrat JavaScript : demandes valides, versions, longueurs Unicode, annulations et cas invalides.
- Transport simulé : réponse corrélée, moteur absent, délai, demande concurrente, arrêt et réponse tardive.
- Fenêtre de contrôle dans Chrome : rendu du texte, absence d’interprétation HTML, arrêt et délai. Le moteur est simulé, jamais présenté comme un résultat Apple réel.
- Ressources, plist, cibles et configuration de compilation contrôlées.

À faire sur Mac : compiler le Swift et lier les frameworks Apple. À faire sur iPhone après installation : vérifier les langues, la fidélité des traductions, les délais, la mémoire, les annulations et le pont Safari. Un simulateur ou une compilation réussie ne valide pas ces points.

Les fichiers et méthodes du framework utilisés nécessitent iOS et un SDK **26.4 ou plus récent**. Cette version couvre l’iOS 27.2.1 déclaré pour l’appareil cible ; la disponibilité effective des modèles reste à vérifier sur cet appareil.

## Compiler sans Mac personnel

Un compte GitHub Free permet de préparer le dépôt. Le workflow fourni est volontairement limité à un **dépôt public** sur les machines Mac standard : les deux tâches sont ignorées si le dépôt est privé. Aucun abonnement Apple, certificat ou secret de signature n’est requis pour cette compilation sans signature. Les ressources de calcul standard des dépôts publics sont gratuites selon GitHub ; le stockage des artefacts a ses propres quotas. Ici, chaque archive est bornée à 50 Mio, conservée un jour, sans cache et sans lancement automatique. [Tarifs Free](https://github.com/pricing), [facturation Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

Avant publication, vérifier le contenu du dossier isolé et décider explicitement de le rendre public. Le projet complet, les rapports iPhone, modèles, vidéos, données privées et certificats HTTPS n’en font pas partie.

Dans un dépôt contenant ce dossier et le workflow :

1. Ouvrir **Actions**.
2. Choisir **Vérifier le prototype natif sur Mac**.
3. Choisir **Run workflow** sur la branche contenant le dossier.
4. Consulter séparément la vérification de l’application et celle du pont Safari.
5. Télécharger les artefacts seulement si la tâche correspondante réussit.

Les résultats attendus s’appellent JPFRNativeLab-UNSIGNED.ipa et éventuellement JPFRSafariLab-UNSIGNED.ipa. **Ces IPA ne sont pas signées et ne peuvent pas être installées telles quelles sur l’iPhone.** La signature et l’installation depuis Windows restent une étape distincte, non validée. La compilation distante ne rend pas automatiquement le prototype utilisable.

La possibilité officielle de tester avec une Personal Team gratuite dans Xcode comporte un renouvellement périodique des profils, généralement après sept jours. Elle ne fournit pas à elle seule une chaîne Windows autonome. La compatibilité de l’extension Safari avec un parcours de signature gratuit n’est pas établie ici. [Compte développeur Apple](https://developer.apple.com/help/account/basics/about-your-developer-account)

## Compiler sur un Mac disponible

Avec Xcode et un SDK iOS ≥ 26.4, Node et [XcodeGen](https://github.com/yonaskolb/XcodeGen) :

    bash native/Scripts/build-macos.sh app
    bash native/Scripts/build-macos.sh safari

Le script exécute le contrôle de transport, génère le projet puis compile sans signature. Le mode app lance aussi les tests Swift du contrat. Le mode safari vérifie l’usage des API avec APPLICATION_EXTENSION_API_ONLY=YES ; une compilation et un test réel restent nécessaires pour confirmer ce parcours.

Les identifiants org.jpfr.prototype… sont ceux d’un prototype non signé. Une future installation devra utiliser des identifiants et une signature appropriés au compte choisi.

## Contrôles de développement

Sans SDK Apple :

    node native/Scripts/check-bridge.mjs
    python native/Scripts/check-project.py

Le second contrôle utilise PyYAML et peut lire la configuration du dépôt isolé. Sur le poste de préparation, les vérifications détaillées de la fenêtre simulée restent hors du dossier public.

Aucun résultat n’est stocké automatiquement par les applications. Les traductions du rapport sont exclues par défaut, puis ajoutées seulement sur choix explicite. Les quatre phrases prioritaires et les 24 références françaises sont des contrôles de travail connus, pas un jeu indépendant ni des traductions certifiées.
