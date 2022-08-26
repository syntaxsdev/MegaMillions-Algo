#Import the Lottery Numbers Archive
$LotteryArchive = Import-CSV -LiteralPath "F:\Lottery\LotteryNumbers.csv" -Delimiter ","

$UpdatedMatrix = [datetime]::parseexact("10/31/2017", 'MM/dd/yyyy', $null)
$OneYearAgo = [datetime]::parseexact("08/01/2021", 'MM/dd/yyyy', $null)

#Grab all the winning numbers and sort by the 2017 matrix change
$WinningCombos = $LotteryArchive.("Winning Numbers")
$Last5YWinningCombos = $LotteryArchive| Where-Object {[datetime]::parseexact($_.("Draw Date"), 'MM/dd/yyyy', $null) -ge $UpdatedMatrix} | Select-Object "Winning Numbers"
$Last1YWinningCombos = $LotteryArchive| Where-Object {[datetime]::parseexact($_.("Draw Date"), 'MM/dd/yyyy', $null) -ge $OneYearAgo} | Select-Object "Winning Numbers"
$Total = $Last5YWinningCombos.Count


#LOG FILES
$LogFile = "F:\Lottery\Log.txt"
"[NEW LOG]" > $LogFile

#Make 6 sections, from smallest to largest
$s1 = @()
$s2 = @()
$s3 = @()
$s4 = @()
$s5 = @()
$number_archive = @()
$number_archive_1Y = @()

#Analysis Variables#

$chances_under10 = 0
$chances_under20 = 0
$chances_multiple_under10 = 0
$chances_multiple_under20 = 0
$mult10 = 0
$mult20 = 0
#######


foreach ($combo in $Last5YWinningCombos) {
    $split = $combo.('Winning Numbers').split(" ")
    $s1 += $split[0];$s2 += $split[1];$s3 += $split[2];$s4 += $split[3];$s5 += $split[4];
    #
    $chance_under_10_found = $false
    $chance_under_20_found = $false
    $split | Foreach-Object {

        if ([int]$_ -le 10) { 
            $chances_multiple_under10++; $chance_under_10_found = $true;
        } elseif ([int]$_ -le 20) {
            $chances_multiple_under20++; $chance_under_20_found = $true;
        }

    }
    if ($chances_multiple_under10 -gt 1) {
        $mult10++;
        $chances_multiple_under10 = 0;
    }
    if ($chances_multiple_under20 -gt 1) {
        $mult20++;
        $chances_multiple_under20 = 0;
    }
    if ($chance_under_10_found -eq $true) {
        $chances_under10++
    }
    if ($chance_under_20_found -eq $true) {
        $chances_under20++
    }

}

foreach ($combo in $Last1YWinningCombos) {
    $split = $combo.('Winning Numbers').split(" ")
    $number_archive_1Y += $split
}

Write-Host ("Chances of 10 or less: {0}%`nChances of 20 or less: {1}%`nChances of multiple 10 or less: {2}%`nChances of multiple 20 or less: {3}%" -f `
([math]::Round($chances_under10/$Total, 4)*100), ([math]::Round($chances_under20/$Total, 4)*100), ([math]::Round($mult10/$Total, 4)*100), ([math]::Round($mult20/$Total, 4)*100))

<#
    Number archive stores every single winning number individually
    The count should be the $Total * 5
#>
$number_archive += $s1;$number_archive += $s2;$number_archive += $s3;$number_archive += $s4;$number_archive += $s5;

#Now lets check most and least frequent numbers

#Most Selected Numbers
$SelectedNumbersByFrequency = $number_archive | Group-Object | Sort-Object Count -Descending | Select-Object Count,Name
$SelectedNumbersByFrequency_1Y = $number_archive_1Y | Group-Object | Sort-Object Count -Descending | Select-Object Count,Name
$TenMostFrequent = $SelectedNumbersByFrequency | Select-Object -First 10
$TenLeastFrequent = $SelectedNumbersByFrequency | Select-Object -Last 10

$20MostFrequent = $SelectedNumbersByFrequency | Select-Object -First 20
$20LeastFrequent = $SelectedNumbersByFrequency | Select-Object -Last 20


$HalfMost = $SelectedNumbersByFrequency | Select-Object -First 35
$HalfLeast = $SelectedNumbersByFrequency | Select-Object -Last 35

<#
    FIVE MOST FREQUENT
        17	48
        31	47
        10	47
        14	47
        4	44


    FIVE LEAST FREQUENT
        50	26
        35	25
        55	25
        49	25
        51	21

#>

#Top five most frequent by %
Write-Host "`n`nFive Most Frequent By %"
0..4 | Foreach-Object {
    Write-Host ("$($TenMostFrequent[$_].Name): {0}% (Count: {1})" -f ([math]::Round($TenMostFrequent[$_].Count/$number_archive.Count, 4)*100), $TenMostFrequent[$_].Count)
}

#Top five least frequent by %
Write-Host "`n`nFive Least Frequent By %"
4..0 | Foreach-Object {
    Write-Host ("$($TenLeastFrequent[$_].Name): {0}% (Count: {1})" -f ([math]::Round($TenLeastFrequent[$_].Count/$number_archive.Count, 4)*100), $TenLeastFrequent[$_].Count)
}


<#
#Hmm, the numbers are more random than I thought. To make an algorithm that would work, would need to include generation bias

We need to make some assumptions here.
Let's generate 100 numbers, each with an evenly split bias every 20 numbers.

#>


#Let's start with making some helpers
function remove {
    param([PSCustomObject]$arr, $value)
        return $arr | Where-Object { $_ -ne $value }
}


function random_number {
    param([int]$min, [int]$max)

    return Get-Random -Minimum $min -Maximum $max

}

function good_combo {
    param([string]$combo, [PSCustomObject]$guessList)

    $arr = $combo.split(" ")
    $c = ($arr | Sort-Object) -join "-"
    <#
    What could we deem not a good combo?
    
    i. If it's a previous combination
    ii. Repitition
    iii. Check if already generated
    #>

    #i. Previous combo
    foreach ($UsedCombo in $WinningCombos) {
        if ($c -eq ($UsedCombo.split(" ") -join "-")) {
            "[Previous Winning Combo]: $c" >> $LogFile
            return $false
        } 
    }

    if ($guessList -ne $null) {
        foreach ($UsedCombo in $guessList) {
            $used = ($UsedCombo.split(" ") | Sort-Object) -join "-"
            if ($c -eq $used) {
                "[Guess List Duplicate Combo]: $c" >> $LogFile
                return $false
            }
        }
    }
    #ii. Repition (brute force)
    if ( ("05" -in $arr -and "10" -in $arr -and "15" -in $arr) -or `
        ("05" -in $arr -and "15" -in $arr -and "35" -in $arr) -or `
        ("05" -in $arr -and "10" -in $arr -and "25" -in $arr) -or `
        ("01" -in $arr -and "02" -in $arr -and "03" -in $arr) -or `
        ("30" -in $arr -and "40" -in $arr -and "50" -in $arr)
    ) {
        return $false
    }
    return $true
}

function generate_lottery_numbers {
    param([int]$min, [int]$max)
    if ($min -eq 0) {
        $min = 1
    }
    $list = @()
    $min..$max | Foreach-Object { if ($_ -lt 10) {
        $list += "0$($_)"
    } 
    else {
        $list += $_
        }
    }
    return $list
}

function RandomMegaball {
    return Get-Random -Minimum 1 -Maximum 25
}

function sort_combos {
    param([PSCustomObject] $numbers)
    $combos = @()
        foreach ($combo in $numbers) {
            $combos += ($combo.split(" ") | Sort-Object) -join " "
        }
    return $combos
}

#GENERATORS

<#
    Bias generation 1
    -----------------
    Pick from top 10's (most and least). 
    i. Generate how many will be picked from each side.
#>
function Gen1 {
    $Combo = ""
    #Create temps
    $TenLeast = $TenLeastFrequent.Name
    $TenMost = $TenMostFrequent.Name

    $PicksFromMost = Get-Random -Minimum 1 -Maximum 5
    $PicksFromLeast = 5 - $PicksFromMost

    1..$PicksFromMost | Foreach-Object {
        $Picked = ($TenMost | Get-Random)
        $TenMost = remove -arr $TenMost -value $Picked
        $Combo += $Picked + " "
    }
    1..$PicksFromLeast | Foreach-Object {
        $Picked = ($TenLeast | Get-Random)
        $TenLeast = remove -arr $TenLeast -value $Picked
        $Combo += $Picked + " "
    }
    return $Combo.Substring(0, $Combo.length-1) + " $(RandomMegaball)"
}

#GENERATORS

<#
    Bias generation 1
    -----------------
    Pick from top 10's (most and least). 
    i. Generate how many will be picked from each side.
#>
function Gen1Beta {
    $Combo = ""
    #Create temps
    $20Least = $20LeastFrequent.Name
    $20Most = $20MostFrequent.Name

    $PicksFromMost = Get-Random -Minimum 1 -Maximum 5
    $PicksFromLeast = 5 - $PicksFromMost

    1..$PicksFromMost | Foreach-Object {
        $Picked = ($20Most | Get-Random)
        $20Most = remove -arr $20Most -value $Picked
        $Combo += $Picked + " "
    }
    1..$PicksFromLeast | Foreach-Object {
        $Picked = ($20Least | Get-Random)
        $20Least = remove -arr $20Least -value $Picked
        $Combo += $Picked + " "
    }
    return $Combo.Substring(0, $Combo.length-1) + " $(RandomMegaball)"
}

<#
    Bias generation 2
    -----------------
    Pick from both halfs
    i. Generate how many will be picked from each side.
#>
function Gen2 {
    $Combo = ""
    #Create temps
    $HalfM = $HalfMost.Name
    $HalfL = $HalfLeast.Name

    $PicksFromMost = Get-Random -Minimum 1 -Maximum 5
    $PicksFromLeast = 5 - $PicksFromMost

    1..$PicksFromMost | Foreach-Object {
        $Picked = ($HalfM | Get-Random)
        $HalfM = remove -arr $HalfM -value $Picked
        $Combo += $Picked + " "
    }
    1..$PicksFromLeast | Foreach-Object {
        $Picked = ($HalfL | Get-Random)
        $HalfL = remove -arr $HalfL -value $Picked
        $Combo += $Picked + " "
    }
    return $Combo.Substring(0, $Combo.length-1) + " $(RandomMegaball)"
}

<#
    Bias generation 3
    -----------------
    Algorithm driven
    i. Pick at most 2 from under 20
    ii. Rest are free-reign
#>
function Gen3 {
    $Combo = ""
    #Create temps
    $Under20 = generate_lottery_numbers -max 20
    
    $X1 = $Under20 | Get-Random
    $X2 = (remove -arr $Under20 -value $X1) | Get-Random
    $List = generate_lottery_numbers -min 21 -max 70


    #Set first two under 20
    $Combo += "$X1 $X2 "

    1..3 | Foreach-Object {
        $Picked = $List | Get-Random
        $List = remove -arr $List -value $Picked
        $Combo += "$Picked "
    }
    return $Combo.Substring(0, $Combo.length-1) + " $(RandomMegaball)"
}


function PickNumbers {
    Param([int]$gen)

    $Guesses = @()
    

    #20 Gen1 combos
    1..$gen | Foreach-Object {
        $Gen1 = Gen1
        if ((good_combo -combo $Gen1 -guessList $Guesses) -eq $true)
        {
            $Megaball = random_number -min 1 -max 25
            $Guesses += $Gen1 + " $Megaball"
        }
    }

     #20 Gen2 combos
     1..$gen | Foreach-Object {
        $Gen2 = Gen2
        if ((good_combo -combo $Gen2 -guessList $Guesses) -eq $true)
        {
            $Megaball = random_number -min 1 -max 25
            $Guesses += $Gen2  + " $Megaball"
        }
    }

         #20 Gen3 combos
         1..$gen | Foreach-Object {
            $Gen3 = Gen3
            if ((good_combo -combo $Gen3 -guessList $Guesses) -eq $true)
            {
                $Megaball = random_number -min 1 -max 25
                $Guesses += $Gen3 + " $Megaball"
            }
        }

    return $Guesses
}



#$BackTest = PickNumbers -gen 10000
#$Last5Y = $LotteryArchive| Where-Object {[datetime]::parseexact($_.("Draw Date"), 'MM/dd/yyyy', $null) -ge $UpdatedMatrix}

function CheckRewards {
    param([string]$guessCombo, [string]$guessMegaball, [string]$winningCombo, [string]$winningMegaball)
    $guess = ($guessCombo.split(" ") | Sort-Object) -join " "
    $winning = ($winningCombo.split(" ") | Sort-Object) -join " "

    #foreach ($draw in $Last5YWinningCombos) {
    #    $number = ($draw."Winning Numbers".split(" ") | Sort-Object) -join " "
    #    $mball = $draw."Mega Ball"
    #    $multiplier = $draw.$multiplier

    #Jackpot Match
    if ($winning -eq $guess -and $winningMegaball -eq $guessMegaball) {
        return "Jackpot"
    }
    #1M prize
    elseif ($winning -eq $guess){
        return 1000000
    }
    #Complex Match logic
    else {
        $number_matches = 0

        $guess.split(" ") | foreach-object {
            if ($winning.indexOf($_) -ge 0) {
                $number_matches ++;
            }
        }
        #Tally up
        switch($number_matches) {
            #4 Match logic
            4 {
                if ($guessMegaball -eq $winningMegaball){
                    return 10000
                }else {
                    return 500
                }
            }
            #3 Match Logic
            3 {
                if ($guessMegaball -eq $winningMegaball){
                    return 200
                }else {
                    return 10
                }
            }
            #2 Match logic
            2 {
                if ($guessMegaball -eq $winningMegaball){
                    return 10
                }
            }
            #1 Match logic
            1 {
                if ($guessMegaball -eq $winningMegaball){
                    return 4
                }
            }
            #0 Match logic
            0 {
                if ($guessMegaball -eq $winningMegaball){
                    return 2
                }
            }
        }
        return 0

    }

    #}
}



function CheckBatchWin {
    param([PSCustomObject]$guessList, $winningNumber, $winningMegaball, $megaplier, $jackpot)

    $rewards = 0
    foreach ($guess in $guessList) {
        $split = $guess.split(" ")
        $combo = $split[0..4]
        $megaball = $split[-1]
        #Write-Host "Guess: $combo | Megaball: $megaball | Orig: $guess"
        $reward = CheckRewards -guessCombo $combo -guessMegaball $megaball -winningCombo $winningNumber -winningMegaball $winningMegaball
        if ($reward -eq "Jackpot") {
            $rewards += $jackpot
        }
        else {
            $rewards += $reward
            if ($reward -gt 0) {
                #Write-Host "Prize!: `$$reward"
            }
        }
    }
    return "Spent: `$$($guessList.length * 2)`n`Rewards:`$$rewards"
}



$gen1winners = @()
1..10000 | foreach-object {
    $gen1winners += Gen1 
}

$gen1betawinners = @()
1..10000 | foreach-object {
    $gen1betawinners += Gen1Beta
}

$gen2winners = @()
1..10000 | foreach-object {
    $gen2winners += Gen2 
}

$gen3winners = @()
1..10000 | foreach-object {
    $gen3winners += Gen3 
}