#include <hunspell/hunspell.hxx>
#include <string>

int main() {
    Hunspell hunspell(NULL, NULL);
    std::string word = "";
    hunspell.suggest(word);
    hunspell.spell(word);
    return 0;
}
