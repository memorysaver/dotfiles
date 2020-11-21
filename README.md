# dotfiles
[![Built with Spacemacs](https://cdn.rawgit.com/syl20bnr/spacemacs/442d025779da2f62fc86c2082703697714db6514/assets/spacemacs-badge.svg)](http://spacemacs.org)

## Installation Guide
### Run Installation scrips

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/install.sh)"
```

### Setup Github

```bash

# copy ssh key to clipboard for adding to github.com
pbcopy < ~/.ssh/id_rsa.pub

# test connection
ssh -T git@github.com
```

### Install Spacemacs

```bash
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
apt-get install emacs
```
