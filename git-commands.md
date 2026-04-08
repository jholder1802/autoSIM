# Allgemeine Funktionen
git status

# if changed files:
git add .
git commit -m "..."

git checkout main

# Wenn neuere Version:
git update-upstream

# Dann zurück zu eigenem branch
git switch -

# ODER 
git checkout feature-jh

# Arbeiten am Feature Branch
# Änderungen hinzufügen:
git add .
git commit -m "Beschreibung der Änderung"
# Regelmäßig deinen Branch prüfen:
git status
git log --oneline --graph
# Fertig? Dann pushen:
git push -u origin feature-jh
# Upstream synchron halten: Hol die neuesten Änderungen von upstream/main:
git fetch upstream
# Rebase deinen Feature Branch auf den aktuellen main:
git checkout feature-jh
git rebase upstream/main
# Vorteil Rebase: Lineare History - Keine Merge-Commits, sauber für Pull Requests - Danach ggf. force push, wenn du schon bei origin gepusht hattest:
git push -f origin feature-jh
# Nach Merge: Wenn dein Feature Branch gemerged ist:
# auf main wechseln
git checkout main
# Upstream holen
git fetch upstream
git reset --hard upstream/main
# Fork aktualisieren
git push origin main -f
# Danach kannst du den Feature Branch löschen:
git branch -d feature-jh
git push origin --delete feature-jh
## Wichtige Regeln für dich
# Nie direkt in main arbeiten
# Immer rebase auf upstream/main vor Merge/PR
# Fork = origin nur für Pushes
# Upstream = Quelle der Wahrheit
# Submodules oder externe Ordner nur als eigenständige Repos, nie committen ins Hauptrepo
# Regelmäßig git fetch upstream → bleibt sauber

# Du kannst einen Alias für Rebase + Push einrichten:
git config --global alias.sync '!git fetch upstream && git rebase upstream/main && git push -f'
# Dann einfach:
git checkout feature-jh
git sync