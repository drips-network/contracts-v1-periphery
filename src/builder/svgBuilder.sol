// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable quotes
pragma solidity ^0.8.7;
import "./baseBuilder.sol";

contract DefaultSVGBuilder is BaseBuilder {
    // temporary background for testing animations
    string public constant DEFAULT_BACKGROUND =
        '<g mask="url(&quot;#SvgjsMask1077&quot;)" fill="none">'
        '    <rect width="350" height="350" x="0" y="0" fill="rgba(24, 22, 75, 1)"></rect>'
        '    <path d="M221.93019150067744 62.8151000845344L235.60207442586116-47.66291972726084 145.37609012030754-11.209255816025902z"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float3"></path>'
        '    <path d="M330.081,342.943C344.391,343.818,358.134,335,364.366,322.088C369.987,310.442,364.249,297.484,357.281,286.59C350.991,276.755,341.708,269.524,330.081,268.482C316.137,267.232,299.693,268.585,292.886,280.819C286.171,292.887,295.267,306.449,302.362,318.298C309.169,329.667,316.855,342.134,330.081,342.943"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float2"></path>'
        '    <path d="M99.13056209708833 305.70472846998604L204.30615863479292 279.5879473911833 139.69897833687094 210.3052287967687z"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float1"></path>'
        '    <path d="M32.57615034811867 269.43053307196885L-24.855865045747862 279.5573469423714-14.72905117534529 336.98936233623795 42.70296421852124 326.8625484658354z"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float1"></path>'
        '    <path d="M206.47307568062772 168.5039948964722L209.31122705362966 87.22997332393318 128.03720548109067 84.39182195093122 125.1990541080887 165.66584352347024z"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float1"></path>'
        '    <path d="M97.24706040905724 312.18146715509135L12.30054945751776 277.76664179623117 22.064626238193256 357.28866564739536z"'
        '          fill="rgba(31, 31, 85, 1)" class="triangle-float1"></path>'
        "</g> <defs>"
        '<mask id="SvgjsMask1077">'
        '    <rect width="350" height="350" fill="#ffffff"></rect>'
        "</mask>"
        "<style>@keyframes float1 { 0%{transform: translate(0, 0)} 50%{transform: translate(-10px, 0)} 100%{transform:"
        "    translate(0, 0)} } .triangle-float1 { animation: float1 5s infinite; } @keyframes float2 { 0%{transform:"
        "    translate(0, 0)} 50%{transform: translate(-5px, -5px)} 100%{transform: translate(0, 0)} } .triangle-float2 {"
        "    animation: float2 4s infinite; } @keyframes float3 { 0%{transform: translate(0, 0)} 50%{transform: translate(0,"
        "    -10px)} 100%{transform: translate(0, 0)} } .triangle-float3 { animation: float3 6s infinite; }"
        "</style>"
        "</defs>";

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerCycle,
        bool active
    ) external pure override returns (string memory) {
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory nftTypeStr = Strings.toString(nftType);
        string memory supportRate = _toTwoDecimals(amtPerCycle);
        string memory svg = Base64.encode(bytes(_buildSVG(projectName, tokenIdStr, supportRate)));
        string memory imageObj = string(abi.encodePacked("data:image/svg+xml;base64,", svg));
        return
            _buildJSON(
                projectName,
                tokenIdStr,
                nftTypeStr,
                supportRate,
                active,
                streaming,
                imageObj
            );
    }

    function buildMetaData(
        string memory projectName,
        uint128 tokenId,
        uint128 nftType,
        bool streaming,
        uint128 amtPerCycle,
        bool active,
        string memory ipfsHash
    ) external pure override returns (string memory) {
        string memory supportRate = _toTwoDecimals(amtPerCycle);
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory nftTypeStr = Strings.toString(nftType);
        return
            _buildJSON(
                projectName,
                tokenIdStr,
                nftTypeStr,
                supportRate,
                active,
                streaming,
                ipfsHash
            );
    }

    function _buildSVG(
        string memory projectName,
        string memory tokenId,
        string memory supportRate
    ) internal pure returns (string memory) {
        // not optimized for gas-usage because it is only a testing svg
        return
            string(
                abi.encodePacked(
                    '<svg class="svgBody" width="350" height="350" viewBox="0 0 350 350" fill="white" xmlns="http://www.w3.org/2000/svg"><style>svg { background-color: #2980B9;}</style>',
                    DEFAULT_BACKGROUND,
                    '<text dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" y="100px" class="small" font-size="25px" fill="#FFFFFF">\xf0\x9f\x8c\xb1 ',
                    projectName,
                    ' \xf0\x9f\x8c\xb1</text><text  y="50%" dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="40px" fill="#FFFFFF">--',
                    tokenId,
                    '--</text><text  y="270" dominant-baseline="middle" x="50%" text-anchor="middle" font-family="Courier New, Courier, Lucida Sans Typewriter" font-size="30px" fill="#FDC034" >',
                    supportRate,
                    " DAI",
                    "</text></svg>"
                )
            );
    }
}
