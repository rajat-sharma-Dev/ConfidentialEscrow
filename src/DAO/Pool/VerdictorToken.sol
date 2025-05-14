// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title VerdictorToken
 * @author Yug Agarwal
 * @notice An ERC20-compatible token with elastic supply (rebasing)
 * @dev This token adjusts its total supply to track the USD value of the StakingPool
 *                                                                        
                         .            .                                   .#                        
                       +#####+---+###+#############+-                  -+###.                       
                       +###+++####+##-+++++##+++##++####+-.         -+###+++                        
                       +#########.-#+--+####++###- -########+---+++#####+++                         
                       +#######+#+++--+####+-..-+-.###+++########+-++###++.                         
                      +######.     +#-#####+-.-------+############+++####-                          
                     +####++...     ########-++-        +##########++++++.                          
                    -#######-+.    .########+++          -++######+++-                               
                    #++########--+-+####++++-- . ..    .-#++--+##+####.                              
                   -+++++++++#####---###---.----###+-+########..-+#++##-                            
                   ++###+++++#####-..---.. .+##++++#++#++-+--.   .-++++#                             
                  .###+.  .+#+-+###+ ..    +##+##+#++----...---.  .-+--+.                            
                  ###+---------+####+   -####+-.......    ...--++.  .---.                           
                 -#++++-----#######+-  .-+###+.... .....      .-+##-.  .                            
                 ##+++###++######++-.   .--+---++---........  ...---.  .                            
                -####+-+#++###++-.        .--.--...-----.......--..... .                            
                +######+++###+--..---.....  ...---------------.. .. .  .                            
               .-#########+#+++--++--------......----++--.--.  .--+---.                             
                -+++########++--++++----------------------.--+++--+++--                             
           .######-.-++++###+----------------------..---++--++-+++---..                             
           -##########-------+-----------------------+-++-++----..----+----+#####++--..             
           -#############+..  ..--..----------.....-+++++++++++++++++##################+.           
           --+++++#########+-   . ....  ....... -+++++++++++++++++++############-.----+##-          
           -----....-+#######+-             .. -+++++++++++++++++++++##+######+.       +++.         
           --------.....---+#####+--......----.+++++++++++++++++++++##+-+++##+.        -++-         
           -------...   .--++++++---.....-----.+++++++++++++++++++++++. -+++##-        .---         
           #################+--.....-------.  .+++++++++++++++++++++-       -+-.       .---         
           +#########++++-.. .......-+--..--++-++++++++++++++++++++-         .-... ....----         
           -#####++---..   .--       -+++-.  ..+++++++++++++++++++--        .-+-......-+---         
           +####+---...    -+#-   .  --++++-. .+++++++++++++++++++---        --        -+--         
           ++++++++++--....-++.--++--.--+++++-.+++++++++++++++++++---. .......         ----         
          .--++#########++-.--.+++++--++++###+-++++++++++++++++++++----   .-++-        ----         
           .-+#############+-.++#+-+-++#######-++++++++++++++++++++----   -++++-      ..---         
          .---+############+.+###++--++#####++-+++++++++++++++++++++-------++++-........-+-         
           --+-+##########-+######+++++-++++++-++++++++++++++++++++++-----.----.......---+-         
          .--+---#######..+#######+++++++--+++-+++++++++++++++++++++++-----------------+++-         
          .++--..-+##-.-########+++++---++ .+-.+++++++++++++++++++++++++++++++++++---+++++-         
          -+++. ..-..-+#########++-++--..--....+++++++++++++++++++++++++++++++++++++++++++-         
          -++-......-+++############++++----- .+++++++++++++++++++++++++++++++++++++++++++-         
          +##-.....---+#######+####+####+--++-.+++++++++++++++++++++++++++++++++++++++++++-         
         .#+++-...-++######++-+-----..----++##-+++++++++++++++++++++++++++++++++++++++++++-         
         .+++--------+##----+------+-..----+++-+++++++++++++++++++++++++++++++++++++++++++-         
          ----.-----+++-+-...------++-----...--+++++++++++++++++++++++++++++++++++++++++++-         
         .-..-.--.----..--.... ....++--.  ....-+++++++++++++++++++++++++++++++++++++++++++-         
          -----------.---..--..   ..+.  . ... .+++++++++++++++++++++++++++++++++++++++++++-         
        .+#+#+---####+-.    .....--...   .    .+++++++++++++++++++++++++++++++++++++++++++-         
        -+++++#++++++++.    ..-...--.. ..     .+++++++++++++++++++++++++++++++++++++++++++-         
        ++++++-------++--   . ....--.. . . .. .+++++++++++++++++++++++++-+----------...             
        -++++--++++.------......-- ...  ..  . .---------------...                                   
        -++-+####+++---..-.........                                                                  
          .....                                                                                      
 */
contract VerdictorToken is Ownable {
    string public name = "Verdictor Token";
    string public symbol = "VDT";
    uint8 public decimals = 18;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 epoch, uint256 totalSupply, uint256 targetSupply);

    // Rebase variables
    uint256 private _totalSupply;
    uint256 private _scalingFactor = 10**18; // Initial 1:1 scaling
    uint256 private _rebaseEpoch = 0;
    
    // User balances stored as "gons" (scaled shares)
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Trigger a rebase to adjust supply to match target USD value
     * @dev Only callable by owner (StakingPool)
     * @param targetSupply The desired supply after rebase
     */
    function rebase(uint256 targetSupply) external onlyOwner returns (uint256) {
        if (targetSupply == _totalSupply) {
            emit Rebase(_rebaseEpoch, _totalSupply, targetSupply);
            return _totalSupply;
        }

        // Calculate new scaling factor
        _rebaseEpoch++;
        uint256 prevScalingFactor = _scalingFactor;
        
        // Update total supply and scaling factor
        _totalSupply = targetSupply;
        _scalingFactor = (_totalSupply * prevScalingFactor) / _totalSupply;
        
        emit Rebase(_rebaseEpoch, _totalSupply, targetSupply);
        return _totalSupply;
    }

    /**
     * @notice Mints new tokens (properly handles gon calculations)
     * @dev Only callable by owner (StakingPool)
     * @param to Recipient of the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        uint256 gonAmount = amount * _scalingFactor / 10**18;
        _gonBalances[to] += gonAmount;
        _totalSupply += amount;
        
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Burns tokens (properly handles gon calculations)
     * @dev Only callable by owner (StakingPool)
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public onlyOwner {
        uint256 gonAmount = amount * _scalingFactor / 10**18;
        _gonBalances[msg.sender] -= gonAmount;
        _totalSupply -= amount;
        
        emit Transfer(msg.sender, address(0), amount);
    }

    // ERC20 Standard functions that handle the gon conversion
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _gonBalances[account] * 10**18 / _scalingFactor;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        uint256 gonAmount = amount * _scalingFactor / 10**18;
        _gonBalances[msg.sender] -= gonAmount;
        _gonBalances[to] += gonAmount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowedFragments[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowedFragments[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _allowedFragments[from][msg.sender] -= amount;
        
        uint256 gonAmount = amount * _scalingFactor / 10**18;
        _gonBalances[from] -= gonAmount;
        _gonBalances[to] += gonAmount;
        
        emit Transfer(from, to, amount);
        return true;
    }

    // Helper function to get current scaling factor
    function getScalingFactor() external view returns (uint256) {
        return _scalingFactor;
    }
}
