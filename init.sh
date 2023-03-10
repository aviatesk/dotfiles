ln -sf ~/dotfiles/.env.zsh ~/.env.zsh
ln -sf ~/dotfiles/.aliases.zsh ~/.aliases.zsh

echo "[ -f .env.zsh ] && source .env.zsh" >> ~/.zshrc
echo "[ -f .aliases.zsh ] && source .aliases.zsh" >> ~/.zshrc

ln -sf ~/dotfiles/.gitconfig ~/.gitconfig
ln -sf ~/dotfiles/.gitconfig_global ~/.gitconfig_global

mkdir -p ~/.julia/config/
ln -sf ~/dotfiles/startup.jl ~/.julia/config/startup.jl
