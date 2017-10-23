import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.geom.ColorTransform;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.SharedObject;
import utils.debug.Stats;


const RAD2DEG:Number = 180 / Math.PI;
const FREQUENCE: uint = stage.frameRate;
const HEALTHBAR_WIDTH: Number = 300;


const MAX_HEALTH: Number = 100;
const ENEMY_DAMAGE: Number = 2;
const BASE_N_ENEMY: uint = 20;
const EXP_N_ENEMY: Number = 1.45; //facteur exponentiel de l'augmentation du nb d'ennemis
const BASE_TIME_PER_ENEMY: Number = 0.5; //temps donné en secondes pour chaque ennemi apparu au début de la première vague
const MULT_TIME_PER_ENEMY: Number = 0.9; //ce temps est multiplié par ce facteur à chaque vague (<1)
const SPEED_MIN:int = 2;
const SPEED_MAX:int = 7;
const SHOTS_SPEED: Number = 20;
const SCORE_ADD: int = 5000;
const SHOOT_COOLDOWN: uint = FREQUENCE / 10;

var sharedData: SharedObject = SharedObject.getLocal("turret_info");

var waveNumber: uint = 0;
var waveTimer: uint = 0;
var health: Number = MAX_HEALTH;

var finalExplosion: FinalExplosion;

var gameOver: Boolean = false;
var displayGameOver: Boolean = false;
var score: int = 0;
var colors:Vector.<int> = new <int>[0x009900, 0xFF9900, 0x6699FF];
var hud: Hud;
var shield: Shield;
var shieldEffect: Boolean;
var player:Player;
var shootTimer: uint;
var shots: Vector.<Shot> = new <Shot> [];
var shotsSpeeds: Array = [];
var enemies: Vector.<Enemy> = new <Enemy>[];
var enemiesSpeeds: Vector.<Number> = new <Number>[];
var explosions: Vector.<Explosion> = new <Explosion>[];
var rectangleStage: Rectangle = new Rectangle(0, 0, stage.stageWidth, stage.stageWidth);

if (sharedData.data.highScore == null) sharedData.data.highScore = 0;
addChild(new Stats()); // affichage des statistiques (FPS, MS, MEM etc...)
shield = createShield();
player = createPlayer(0, 0);
hud = createHud(0);
trace(sharedData.data.highScore);

function gameLoop (pEvent:Event): void {
	if (!gameOver) {
		doWaves();
		doActionEnemies();
		doActionShots();
		if (shootTimer > 0) shootTimer--;
		if (shieldEffect) doActionShield();
		doActionPlayer();
		doActionHud();
	}
	doActionExplosions();
	doGameOver();
}

// Ecouteur ajouté à la scène, écoute l'événement Event.ENTER_FRAME et exécute la fonction gameLoop à la réception de cet événement à chaque frame
addEventListener(Event.ENTER_FRAME, gameLoop);
addEventListener(MouseEvent.MOUSE_DOWN, createShot);

function doWaves(): void {
	if (waveTimer == 0) {
			var lNEnemy: uint;
			createEnemies(lNEnemy = BASE_N_ENEMY + Math.pow(EXP_N_ENEMY, waveNumber) - 1); //le nombre d'ennemis augmente de façon exponentielle à chaque vague
			waveTimer = FREQUENCE * lNEnemy * BASE_TIME_PER_ENEMY * Math.pow(MULT_TIME_PER_ENEMY, waveNumber); //le temps donné au joueur par ennemi diminue à chaque vague
			waveNumber++;
		}
	waveTimer--;
}

function doGameOver(): void {
	if (gameOver && finalExplosion.currentFrame == finalExplosion.totalFrames) {
		var lGameOverScreen: GameOverScreen;
		removeChild(finalExplosion);
		addChild(lGameOverScreen = new GameOverScreen());
		lGameOverScreen.txtScore.text = "SCORE : " + score;
		lGameOverScreen.txtHighScore.text = "HIGH SCORE : " + sharedData.data.highScore;
		sharedData.flush();
		removeEventListener(Event.ENTER_FRAME, gameLoop);
	}
	if (!gameOver && !displayGameOver && health == 0) {
		removeEventListener(MouseEvent.MOUSE_DOWN, createShot);
		removeChild(hud);
		for (var i: int = enemies.length - 1; i >= 0; i--)
			destroyEnemy(enemies[i], i); 
		for (i = shots.length - 1; i >= 0; i--)
			destroyShot(shots[i], i);
		destroyShield();
		destroyPlayer();
		gameOver = true;
	}
}

function createHud(pScore:int): Hud {
	var lHud:Hud = new Hud();
	var lGraduation: HealthBarGraduation;
	var lNGradutations: uint = health / ENEMY_DAMAGE;
	var lSpaceBetweenGradutations: Number = lHud.mcHealthBar.width / lNGradutations;
	addChild(lHud);
	lHud.txtScore.text = "Score : " + pScore;
	lHud.txtWave.text = "Wave : " + waveNumber;
	lHud.txtHighScore.text = "High Score :" + sharedData.data.highScore;
	for (var i = 1; i < lNGradutations; i++) {
		lHud.mcHealthBar.addChild(lGraduation = new HealthBarGraduation);
		lGraduation.x = i * lSpaceBetweenGradutations;
	}
	return lHud;
}

function doActionHud(): void {
	if (score > sharedData.data.highScore)
		sharedData.data.highScore = score;
	hud.txtScore.text = "Score : " + score + "\nWave " + waveNumber;
	hud.txtWave.text = "Wave : " + waveNumber;
	hud.txtHighScore.text = "High Score :" + sharedData.data.highScore;
	hud.mcHealthMask.width = health * hud.mcHealthBar.width / MAX_HEALTH;
}

function createShield(): Shield {
	var lShield: Shield;
	mcGame.addChild(lShield = new Shield());
	lShield.mcEffect.visible = false;
	return lShield;
}

function destroyShield(): void {
	var lShieldGlobalCoords: Point = mcGame.localToGlobal(new Point(shield.x, shield.y));
	mcGame.removeChild(shield);
	addChild(finalExplosion = new FinalExplosion());
	finalExplosion.x = lShieldGlobalCoords.x;
	finalExplosion.y = lShieldGlobalCoords.y;
}

function doActionShield(): void {
	if (shield.mcContent.currentFrame < shield.mcContent.totalFrames) {
		shield.mcContent.play();
	} else {
		shield.mcContent.gotoAndStop(0);
		shieldEffect = false;
	}
}

function createPlayer(pX:int, pY:int): Player {
	var lPlayer:Player = new Player();
	lPlayer.x = pX;
	lPlayer.y = pY;
	lPlayer.mcEffect.visible = false;
	mcGame.addChild(lPlayer);
	return lPlayer;
}

function destroyPlayer(): void {
	mcGame.removeChild(player);
}

function doActionPlayer():void {
	var lRadian:Number = Math.atan2(mcGame.mouseY, mcGame.mouseX);	// radian entre la direction droite et la souris
	player.rotation = lRadian * RAD2DEG; // conversion de radian vers les degrés, la valeur est affecté à la rotation du player
}

function createShot(pEvent:MouseEvent): void {
	if (shootTimer == 0) {
		var lShot: Shot;
		var lShotContainerCoords: Point;
		mcGame.addChild(lShot = new Shot());
		shots.push(lShot);
		shotsSpeeds.push([SHOTS_SPEED * Math.cos(player.rotation / RAD2DEG), SHOTS_SPEED * Math.sin(player.rotation / RAD2DEG)]);
		lShotContainerCoords = mcGame.globalToLocal(player.localToGlobal(new Point(player.mcEffect.x, player.mcEffect.y)));
		lShot.x = lShotContainerCoords.x;
		lShot.y = lShotContainerCoords.y;
		shootTimer = SHOOT_COOLDOWN;
	}
}

function destroyShot(pShot: Shot, i: uint): void {
	pShot.parent.removeChild(pShot);
	shots.splice(i,1);
	shotsSpeeds.splice(i,1);
}

function doActionShots(): void {
	var lShot: Shot;
	var lGlobalShotCoords: Point;
	var lDestroyShot: Boolean;
	var lEnemy: Enemy;

	for (var i: int = shots.length - 1; i >= 0; i--) {
		lDestroyShot = false;
		lShot = shots[i];
		lShot.x += shotsSpeeds[i][0];
		lShot.y += shotsSpeeds[i][1];
		lGlobalShotCoords = mcGame.localToGlobal(new Point(lShot.x, lShot.y));
		if (lGlobalShotCoords.x < -lShot.width || lGlobalShotCoords.x > stage.stageWidth + lShot.width || lGlobalShotCoords.y < -lShot.height || lGlobalShotCoords.y > stage.stageHeight + lShot.height)
			lDestroyShot = true;
		else {
			for (var j: int = enemies.length - 1; j >= 0; j--) {
				lEnemy = enemies[j];
				if (lShot.hitTestObject(lEnemy)) { //lGlobalShotCoords.x, lGlobalShotCoords.y)) {							//lShot.x > lEnemy.x - lEnemy.width / 2 - lShot.width / 2 && lShot.x < lEnemy.x + lEnemy.width / 2 + lShot.width / 2 && lShot.y > lEnemy.y - lEnemy.height / 2 - lShot.height / 2 && lShot.y < lEnemy.y + lEnemy.height / 2 + lShot.height / 2) {
					destroyEnemy(lEnemy, j);
					lDestroyShot = true;
					score += SCORE_ADD;
				}
			}
		}
		if (lDestroyShot)
			destroyShot(lShot, i);
	}
}

function createEnemies(pNEnemy:int):void {
	var lEnemy:Enemy;
	var lRandomIndex:int;
	var lColorTransform:ColorTransform = new ColorTransform();
	var lSpeed:Number;
	var lRangeSpeed:int = SPEED_MAX - SPEED_MIN;
	var lHalfStageWidth:Number = stage.stageWidth / 2;
	var lHalfStageHeight:Number = stage.stageHeight / 2;
	
	for (var i:int = 0; i < pNEnemy; i++){
		lEnemy = new Enemy();
		
		lEnemy.scaleX = (Math.random() < 0.5) ? -1 : 1;
		lEnemy.scaleY = (Math.random() < 0.5) ? -1 : 1;
		lEnemy.x = -lEnemy.scaleX * (Math.random() * lHalfStageWidth + lHalfStageWidth);
		lEnemy.y = -lEnemy.scaleY * (Math.random() * lHalfStageHeight + lHalfStageHeight);
		
		lRandomIndex = Math.floor(Math.random() * colors.length);
		lColorTransform.color = colors[lRandomIndex];
		lEnemy.mcEnemy.mcColor.transform.colorTransform = lColorTransform;
		
		mcGame.addChild(lEnemy);
		enemies.push(lEnemy);
		
		lSpeed = SPEED_MIN + Math.random() * lRangeSpeed;
		lSpeed = Math.round(lSpeed * 20) / 20;
		enemiesSpeeds.push(lSpeed);
		
		lEnemy.cacheAsBitmap = true;
	}
}

function destroyEnemy(pEnemy: Enemy, i: uint): void {
	var lEnemyGlobalCoords: Point = mcGame.localToGlobal(new Point(pEnemy.x, pEnemy.y));
	mcGame.removeChild(pEnemy);
	enemies.splice(i, 1);
	enemiesSpeeds.splice(i, 1);
	createExplosion(lEnemyGlobalCoords.x, lEnemyGlobalCoords.y);
}

function doActionEnemies():void{
	var lEnemy:Enemy;
	var lEnemyGlobalCoords: Point;
	var lSpeed:Number;
	var lXMax:Number = stage.stageWidth / 2;
	var lXMin:Number = -stage.stageWidth / 2;
	var lYMax:Number = stage.stageHeight / 2;
	var lYMin:Number = -stage.stageHeight / 2;
	
	for (var i:int = enemies.length - 1; i >= 0; i--){
		lEnemy = enemies[i];
		lEnemyGlobalCoords = lEnemy.parent.localToGlobal(new Point(lEnemy.x, lEnemy.y));
		lSpeed = enemiesSpeeds[i];
		
		lEnemy.x += lEnemy.scaleX * lSpeed;
		lEnemy.y += lEnemy.scaleY * lSpeed;
				
		if (rectangleStage.contains(lEnemyGlobalCoords.x, lEnemyGlobalCoords.y)) {
			if (lEnemy.x < lXMin + lEnemy.width/2){
				lEnemy.scaleX = 1;
			} else if (lEnemy.x > lXMax - lEnemy.width/2){
				lEnemy.scaleX = -1;
			}
			
			if (lEnemy.y < lYMin + lEnemy.height/2){
				lEnemy.scaleY = 1;
			} else if (lEnemy.y > lYMax - lEnemy.height/2){
				lEnemy.scaleY = -1;
			}
			
			if (shield.mcEffect.hitTestPoint(lEnemyGlobalCoords.x, lEnemyGlobalCoords.y)) {        // && ((lEnemy.x < 0 && lEnemy.scaleX > 0) || (lEnemy.x > 0 && lEnemy.scaleX < 0) || (lEnemy.y < 0 && lEnemy.scaleY > 0) || (lEnemy.y > 0 && lEnemy.scaleY < 0))
				lEnemy.scaleX = lEnemy.x - shield.x < 0 ? -1 : 1;
				lEnemy.scaleY = lEnemy.y - shield.y < 0 ? -1 : 1;
				shieldEffect = true;
				health -= ENEMY_DAMAGE;
			}
		}
	}
}

function createExplosion(pX: Number, pY: Number): void {
	var lExplosion: Explosion;
	addChild(lExplosion = new Explosion());
	lExplosion.x = pX;
	lExplosion.y = pY;
	explosions.push(lExplosion);
}

function destroyExplosion(pExplosion: Explosion, i: uint): void {
	removeChild(pExplosion);
	explosions.splice(i, 1);
}

function doActionExplosions(): void {
	var lExplosion: Explosion;
	for (var i = explosions.length - 1; i >= 0; i--) {
		lExplosion = explosions[i];
		if (lExplosion.currentFrame == lExplosion.totalFrames)
			destroyExplosion(lExplosion, i);
	}
}
