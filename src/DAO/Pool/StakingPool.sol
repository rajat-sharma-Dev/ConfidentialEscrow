// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VerdictorToken} from "./VerdictorToken.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ValidTokensRegistry} from "./ValidTokensRegistry.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title StakingPool 
 * @author Yug Agarwal
 * @dev Users can stake their USDC tokens in this contract to receive Verdictor tokens.
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
contract StakingPool is Ownable {
    error StakingPool__InvalidAmount();
    error StakingPool__InvalidToken();
    error StakingPool__InvalidAddress();

    VerdictorToken private immutable i_verdictorToken;
    ValidTokensRegistry private immutable i_validTokensRegistry;

    modifier ValidToken(address token) {
        if (!i_validTokensRegistry.isValidToken(token)) {
            revert StakingPool__InvalidToken();
        }
        _;
    }

    constructor(address validTokensRegistry) Ownable(msg.sender) {
        if (validTokensRegistry == address(0)) {
            revert StakingPool__InvalidAddress();
        }
        i_verdictorToken = new VerdictorToken();
        i_validTokensRegistry = ValidTokensRegistry(validTokensRegistry);
    }

    function stake(uint256 amount, address token) external ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        i_verdictorToken.mint(msg.sender, amount);
    }

    function unstake(uint256 amount, address token) external ValidToken(token) {
        if (amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        i_verdictorToken.transferFrom(msg.sender, address(this), amount);
        i_verdictorToken.burn(amount);
        IERC20(token).transfer(msg.sender, amount);
    }

    function slice(uint256 amount, address token, address recipient) external onlyOwner ValidToken(token) {
        if(amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        if(recipient == address(0)) {
            revert StakingPool__InvalidAddress();
        }
        IERC20(token).transferFrom(recipient, address(this), amount);
    }

}
