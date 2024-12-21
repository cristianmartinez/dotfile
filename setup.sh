#!/bin/bash
set -e

echo "Starting setup..."

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install or update Homebrew
if ! command_exists brew; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Updating Homebrew..."
    brew update
fi

# Install packages and applications
echo "Installing packages and applications..."
brew install git tmux fish lazygit z asdf direnv php composer jq
brew install --cask iterm2 google-chrome visual-studio-code docker miniconda cursor

# Configure tmux
echo "Configuring tmux..."
cat > ~/.tmux.conf << 'EOF'
# Enable mouse support
set -g mouse on

# Set the default shell to Fish
set-option -g default-shell /opt/homebrew/bin/fish

# Set scrollback buffer to 10,000 lines
set -g history-limit 10000

# Appearance settings
setw -g mode-keys vi
set -g status-bg colour235
set -g status-fg white
set -g status-left "[#S] "
set -g status-right "⌚️ %H:%M %d-%b-%y"

# Pane splitting shortcuts
bind | split-window -h
bind - split-window -v

# Reload configuration shortcut
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Enable pane switching with Alt + arrow keys
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D
EOF

# Configure Fish shell
echo "Configuring Fish shell as default..."
if ! grep -Fxq "$(which fish)" /etc/shells; then
    echo "$(which fish)" | sudo tee -a /etc/shells
fi
chsh -s "$(which fish)"

# Install Laravel CLI globally
echo "Installing Laravel CLI..."
composer global require laravel/installer

# Install Oh My Fish and theme
echo "Setting up Oh My Fish..."
curl -L https://get.oh-my.fish | fish
fish -c "omf install bobthefish"

# Configure Fish
echo "Configuring Fish environment..."
cat >> ~/.config/fish/config.fish << EOF
source /opt/homebrew/opt/z/share/z/z.sh
set -gx PATH /opt/homebrew/bin \$PATH

# Add Composer global binaries to PATH
set -gx PATH \$HOME/.composer/vendor/bin \$PATH

# direnv configuration
direnv hook fish | source

# OpenAI configuration
set -gx OPENAI_API_KEY "your-api-key-here"

# Git aliases
alias g="git"
alias gs="git status"
alias gaa="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gb="git branch"
alias gst="git stash"
alias gstp="git stash pop"
alias gl="git log --oneline"
alias gd="git diff"
alias grh="git reset --hard"
alias grs="git reset --soft"
alias gf="git fetch"
alias gm="git merge"

# Git functions
function gcl
    git clone \$argv
end

function gclcd
    set repo \$argv[1]
    set dir (basename \$repo .git)
    git clone \$repo && cd \$dir
end

# AI-assisted git commit
function gca
    # Get the git diff
    set diff (git diff --cached)
    
    if test -z "$diff"
        echo "No staged changes to commit. Use 'git add' first."
        return 1
    end
    
    # Prepare the prompt for OpenAI
    set prompt "Generate a concise git commit message for these changes:\n$diff\n\nFormat as: <type>: <message>\nTypes: feat|fix|docs|style|refactor|test|chore"
    
    # Call OpenAI API
    set suggested_message (curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"temperature\": 0.7,
            \"max_tokens\": 60
        }" | jq -r '.choices[0].message.content')
    
    # Show the suggested message and allow editing
    echo "Suggested commit message:"
    echo $suggested_message
    
    read -l -P "Use this message? [Y/n/e(edit)]: " confirm
    
    switch $confirm
        case "" "y" "Y"
            git commit -m "$suggested_message"
        case "e" "E"
            read -l -P "Edit message: " edited_message
            git commit -m "$edited_message"
        case "*"
            echo "Commit cancelled"
            return 1
    end
end
EOF

# Install VSCode extensions
echo "Installing VSCode extensions..."
if command_exists code; then
    code --install-extension ms-python.python \
         --install-extension dbaeumer.vscode-eslint
fi

# Configure ASDF
echo "Setting up ASDF version manager..."
set -U fish_user_paths $HOME/.asdf/bin $HOME/.asdf/shims $fish_user_paths
echo "source $(brew --prefix asdf)/libexec/asdf.fish" >> ~/.config/fish/config.fish

# Install Node.js and Python via ASDF
echo "Installing Node.js and Python via ASDF..."
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin add python https://github.com/danhper/asdf-python.git
asdf install nodejs latest && asdf global nodejs latest
asdf install python latest && asdf global python latest

# Initialize Conda for Fish
echo "Initializing Conda..."
conda init fish
source ~/.config/fish/config.fish

echo "Setup complete! Please restart your terminal to apply all changes."